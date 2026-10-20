"""Synthesizes crude placeholder sounds into audio/events/<event_id>/placeholder_N.wav.

They exist only so the game makes noise before the real sound pack is dropped in.
Delete them (python tools/make_placeholder_sfx.py --clean) once real files are added.

Standard library only:  python tools/make_placeholder_sfx.py
"""
import math
import random
import struct
import sys
import wave
import zlib
from pathlib import Path

SR = 22050
EVENTS_DIR = Path(__file__).resolve().parent.parent / "audio" / "events"


# --- building blocks -------------------------------------------------------

def silence(sec):
    return [0.0] * int(sec * SR)


def noise(sec, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def lowpass(x, alpha):
    """One-pole lowpass; alpha in (0, 1], smaller = darker."""
    out, y = [], 0.0
    for s in x:
        y += alpha * (s - y)
        out.append(y)
    return out


def highpass(x, alpha):
    low = lowpass(x, alpha)
    return [a - b for a, b in zip(x, low)]


def osc(sec, freq_fn, shape="sine"):
    """Oscillator whose frequency follows freq_fn(t in 0..1)."""
    n, phase, out = int(sec * SR), 0.0, []
    for i in range(n):
        phase = (phase + freq_fn(i / n) / SR) % 1.0
        if shape == "saw":
            out.append(2.0 * phase - 1.0)
        elif shape == "square":
            out.append(1.0 if phase < 0.5 else -1.0)
        else:
            out.append(math.sin(2 * math.pi * phase))
    return out


def env(x, attack=0.005, decay_power=3.0):
    """Fast attack, polynomial decay to zero at the end."""
    n, a = len(x), max(1, int(attack * SR))
    return [s * (i / a if i < a else (1 - (i - a) / max(1, n - a)) ** decay_power) for i, s in enumerate(x)]


def swell(x, peak=0.5):
    """Rise then fall, peaking at `peak` (0..1) of the duration."""
    n = len(x)
    return [s * ((i / n) / peak if i / n < peak else (1 - i / n) / (1 - peak)) for i, s in enumerate(x)]


def fade_edges(x, sec=0.05):
    n = int(sec * SR)
    return [s * min(1.0, i / n, (len(x) - 1 - i) / n) for i, s in enumerate(x)]


def mix(*parts):
    n = max(len(p) for p, _ in parts)
    out = [0.0] * n
    for p, offset in parts:
        start = int(offset * SR)
        for i, s in enumerate(p):
            if start + i < n:
                out[start + i] += s
    return out


def pad(x, offset):
    return silence(offset) + x


def scale(x, g):
    return [s * g for s in x]


# --- recipes: event_id -> fn(rng, pitch) -> samples ------------------------

def footstep(rng, p):
    return env(lowpass(noise(0.11, rng), 0.12 * p), 0.003, 4)


def axe_swing(rng, p):
    return swell(highpass(lowpass(noise(0.24, rng), 0.35 * p), 0.05), 0.6)


def axe_hit_wood(rng, p):
    knock = env(osc(0.2, lambda t: 190 * p * (1 - 0.3 * t)), 0.001, 5)
    return mix((env(lowpass(noise(0.08, rng), 0.5), 0.001, 3), 0), (scale(knock, 0.9), 0))


def tree_fall(rng, p):
    creak = swell(lowpass(osc(1.1, lambda t: 70 * p + 40 * t + 6 * math.sin(t * 60), "saw"), 0.08), 0.8)
    crash = env(lowpass(noise(0.7, rng), 0.06), 0.002, 2)
    return mix((scale(creak, 0.6), 0), (crash, 1.05))


def player_hurt(rng, p):
    return env(lowpass(osc(0.28, lambda t: 150 * p - 50 * t, "saw"), 0.15), 0.01, 2)


def player_death(rng, p):
    return env(lowpass(osc(1.0, lambda t: 170 * p - 110 * t, "saw"), 0.12), 0.02, 1.5)


def eat(rng, p):
    crunch = lambda: env(lowpass(noise(0.07, rng), 0.4 * p), 0.002, 3)
    return mix((crunch(), 0), (crunch(), 0.13), (crunch(), 0.27))


def pickup_wood(rng, p):
    clack = lambda f: env(osc(0.07, lambda t: f * p), 0.001, 4)
    return mix((clack(420), 0), (clack(320), 0.07))


def pickup_meat(rng, p):
    return mix((env(lowpass(noise(0.18, rng), 0.08), 0.01, 2), 0),
               (scale(env(osc(0.18, lambda t: 240 * p - 80 * t), 0.01, 2), 0.6), 0))


def rustle(sec, rng, brightness=0.5):
    """Leafy rustle: highpassed noise with a few random swells."""
    leaves = highpass(lowpass(noise(sec, rng), brightness), 0.08)
    bumps = [0.4 + 0.6 * abs(math.sin(i / SR * math.pi * rng.uniform(9, 14))) for i in range(len(leaves))]
    return swell([s * b for s, b in zip(leaves, bumps)], 0.4)


def stem_snap(rng, p, freq=2400):
    return mix((env(highpass(noise(0.02, rng), 0.5), 0.0005, 5), 0),
               (scale(env(osc(0.03, lambda t: freq * p), 0.0005, 6), 0.4), 0))


def herb_yarrow_pick(rng, p):
    return mix((scale(rustle(0.35, rng, 0.45 * p), 0.6), 0), (stem_snap(rng, p), 0.22))


def herb_angelica_pick(rng, p):
    # Thick hollow stalk: a crack plus a short resonant "tock".
    hollow = env(osc(0.16, lambda t: 520 * p * (1 - 0.15 * t)), 0.001, 4)
    return mix((scale(rustle(0.3, rng, 0.35 * p), 0.5), 0), (stem_snap(rng, p, 1400), 0.18),
               (scale(hollow, 0.8), 0.18))


def herb_wolfsbane_pick(rng, p):
    # Slow, careful rustle with a faint low drone – you're handling poison.
    drone = swell(osc(0.6, lambda t: 82 * p + 4 * math.sin(t * 20)), 0.5)
    return mix((scale(rustle(0.6, rng, 0.25 * p), 0.6), 0), (scale(drone, 0.35), 0), (stem_snap(rng, p, 1800), 0.42))


def herb_yarrow_use(rng, p):
    # Crushing leaves into a poultice: soft wet squishes.
    squish = lambda: swell(lowpass(noise(0.12, rng), 0.06 * p), 0.3)
    return mix((squish(), 0), (squish(), 0.16), (scale(squish(), 0.7), 0.3))


def herb_angelica_use(rng, p):
    # Crunchy, fibrous stalk chewing – brighter than eating meat.
    crunch = lambda: env(highpass(lowpass(noise(0.06, rng), 0.7 * p), 0.1), 0.001, 3)
    return mix((crunch(), 0), (crunch(), 0.11), (scale(crunch(), 0.8), 0.21), (scale(crunch(), 0.6), 0.33))


def herb_wolfsbane_use(rng, p):
    # Smearing paste on the blade: a gritty scrape plus an eerie falling tone.
    scrape = swell(highpass(lowpass(noise(0.45, rng), 0.5), 0.15), 0.5)
    eerie = swell(osc(0.9, lambda t: (660 - 260 * t) * p + 10 * math.sin(t * 45)), 0.2)
    return mix((scrape, 0), (scale(eerie, 0.35), 0.2))


def herb_wolfsbane_wear_off(rng, p):
    tone = lambda f: env(osc(0.7, lambda t: f * p * (1 - 0.3 * t)), 0.01, 2)
    return mix((scale(tone(520), 0.5), 0), (scale(tone(390), 0.4), 0.12))


def wolf_growl(rng, p):
    rough = osc(0.8, lambda t: 75 * p + 10 * math.sin(t * 40), "saw")
    grit = lowpass(noise(0.8, rng), 0.05)
    return swell(lowpass([a * 0.7 + b * 1.5 for a, b in zip(rough, grit)], 0.1), 0.3)


def wolf_howl(rng, p):
    contour = lambda t: (380 + 260 * math.sin(math.pi * min(t * 1.4, 1.0))) * p + 8 * math.sin(t * 70)
    return swell(osc(1.8, contour), 0.35)


def wolf_bite(rng, p):
    return mix((env(highpass(noise(0.05, rng), 0.3), 0.001, 4), 0),
               (scale(env(osc(0.08, lambda t: 300 * p), 0.001, 5), 0.6), 0.02))


def wolf_hurt(rng, p):
    return env(osc(0.3, lambda t: (950 - 400 * t) * p), 0.005, 1.5)


def wolf_death(rng, p):
    return env(osc(0.8, lambda t: (720 - 480 * t) * p + 15 * math.sin(t * 50)), 0.01, 1.2)


def campfire_ignite(rng, p):
    return swell(lowpass(noise(0.7, rng), 0.25 * p), 0.4)


def campfire_add_wood(rng, p):
    thunk = env(lowpass(noise(0.12, rng), 0.1), 0.002, 3)
    return mix((thunk, 0), *[(scale(env(highpass(noise(0.02, rng), 0.4), 0.001, 3), 0.5), 0.1 + rng.random() * 0.2)
                             for _ in range(4)])


def campfire_extinguish(rng, p):
    return env(highpass(noise(1.0, rng), 0.2), 0.02, 1.5)


def campfire_loop(rng, p):
    bed = scale(lowpass(noise(4.0, rng), 0.03), 0.5)
    pops = [(scale(env(highpass(noise(0.015, rng), 0.3), 0.001, 3), rng.uniform(0.3, 1.0)), rng.random() * 3.9)
            for _ in range(45)]
    return fade_edges(mix((bed, 0), *pops), 0.02)


def war_horn(rng, p):
    vib = lambda base: (lambda t: base * p * (1 + 0.006 * math.sin(t * 30)))
    tone = [a + 0.5 * b for a, b in zip(osc(2.2, vib(98), "saw"), osc(2.2, vib(147), "saw"))]
    return swell(lowpass(tone, 0.06), 0.25)


def ambience_wind(rng, p):
    n = noise(8.0, rng)
    gust = [0.55 + 0.45 * math.sin(2 * math.pi * (i / SR) / 4.0 + 1.3) for i in range(len(n))]
    return fade_edges([s * g for s, g in zip(lowpass(n, 0.02), gust)], 0.4)


def ui_click(rng, p):
    return env(osc(0.05, lambda t: 1200 * p), 0.001, 4)


def ui_hover(rng, p):
    return env(osc(0.04, lambda t: 880 * p), 0.002, 3)


def ui_inventory_open(rng, p):
    # Leather satchel flap: a soft rustle, then a buckle clink.
    flap = swell(lowpass(noise(0.22, rng), 0.12 * p), 0.3)
    clink = env(osc(0.09, lambda t: 2100 * p), 0.0005, 4)
    return mix((flap, 0), (scale(clink, 0.35), 0.16), (scale(clink, 0.2), 0.2))


def ui_inventory_close(rng, p):
    # Flap folding shut: a short rustle and a dull leather thump.
    flap = swell(lowpass(noise(0.16, rng), 0.1 * p), 0.6)
    thump = env(lowpass(osc(0.1, lambda t: 140 * p * (1 - 0.3 * t)), 0.2), 0.002, 3)
    return mix((scale(flap, 0.8), 0), (thump, 0.12))


def spit_place(rng, p):
    # Meat skewered onto the spit: a wet slap, then the bar dropping into the forks.
    slap = env(lowpass(noise(0.1, rng), 0.15 * p), 0.002, 3)
    clack = lambda f: env(osc(0.06, lambda t: f * p), 0.001, 5)
    return mix((slap, 0), (scale(clack(360), 0.6), 0.12), (scale(clack(300), 0.4), 0.17))


def sizzle(sec, rng, density=60):
    """Fat sizzling: bright hiss with a fluttering level and spitting pops."""
    hiss = highpass(lowpass(noise(sec, rng), 0.6), 0.25)
    flutter = [0.55 + 0.25 * math.sin(i / SR * 11.0) + 0.2 * math.sin(i / SR * 3.1) for i in range(len(hiss))]
    pops = [(scale(env(highpass(noise(0.01, rng), 0.5), 0.0005, 4), rng.uniform(0.4, 1.2)), rng.random() * (sec - 0.02))
            for _ in range(int(density * sec))]
    return mix(([h * f * 0.5 for h, f in zip(hiss, flutter)], 0), *pops)


def spit_sizzle_loop(rng, p):
    return fade_edges(sizzle(3.0, rng), 0.03)


def spit_done(rng, p):
    # A last flare of sizzle that dies away, and the spit lifted off its forks.
    flare = env(sizzle(0.8, rng, 40), 0.01, 2)
    lift = env(osc(0.08, lambda t: 330 * p), 0.001, 5)
    return mix((flare, 0), (scale(lift, 0.5), 0.5))


def pickup_cooked_meat(rng, p):
    return mix((env(lowpass(noise(0.16, rng), 0.12), 0.01, 2), 0),
               (scale(env(osc(0.16, lambda t: 300 * p - 60 * t), 0.01, 2), 0.5), 0))


def stone_tap(rng, p, freq=900):
    """Stone-on-stone knock: short noise click plus a dull, quickly damped ring."""
    click = env(highpass(noise(0.015, rng), 0.3), 0.0005, 5)
    ring = env(osc(0.09, lambda t: freq * p * (1 - 0.1 * t)), 0.0005, 6)
    return mix((click, 0), (scale(ring, 0.5), 0))


def mortar_place(rng, p):
    # Herbs dropped into the stone bowl, then the pestle set in.
    return mix((scale(rustle(0.25, rng, 0.4 * p), 0.6), 0), (stone_tap(rng, p), 0.2))


def mortar_grind_loop(rng, p):
    # Pestle circling the bowl: gritty stone friction swelling with each stroke, plus wet crushing.
    sec, strokes = 3.0, 4
    grit = lowpass(highpass(noise(sec, rng), 0.05), 0.35)
    stroke = [0.25 + 0.75 * abs(math.sin(math.pi * strokes * i / (sec * SR))) ** 2 for i in range(len(grit))]
    crush = [(scale(env(lowpass(noise(0.05, rng), 0.12), 0.003, 3), rng.uniform(0.3, 0.7)),
              (k + rng.uniform(0.2, 0.6)) * sec / strokes) for k in range(strokes)]
    return fade_edges(mix(([g * w * 0.6 for g, w in zip(grit, stroke)], 0), *crush), 0.03)


def mortar_done(rng, p):
    # Last scrape, then the pestle knocked on the rim twice.
    scrape = swell(lowpass(highpass(noise(0.25, rng), 0.05), 0.35), 0.4)
    return mix((scale(scrape, 0.6), 0), (stone_tap(rng, p, 820), 0.28), (scale(stone_tap(rng, p, 820), 0.7), 0.42))


def build_saw_loop(rng, p):
    # Hand saw through a log: push and pull strokes, the push a little brighter.
    sec, strokes = 2.0, 4
    rasp = highpass(lowpass(noise(sec, rng), 0.45), 0.12)
    out = []
    for i, r in enumerate(rasp):
        phase = (i / SR) * strokes / sec % 1.0
        push = phase < 0.5
        level = math.sin(math.pi * (phase * 2.0 % 1.0)) ** 1.5
        out.append(r * level * (1.0 if push else 0.7))
    return fade_edges(out, 0.02)


def creak(sec, p, base=95):
    """Wooden creak: a gritty, wobbling sawtooth through a dark filter."""
    wobble = lambda t: base * p * (1 + 0.25 * t) + 12 * math.sin(t * 90) + 6 * math.sin(t * 230)
    return lowpass(osc(sec, wobble, "saw"), 0.07)


def build_stake_drive(rng, p):
    # Wooden mallet on a stake: a low thud with a woody knock.
    thud = env(osc(0.22, lambda t: 105 * p * (1 - 0.35 * t)), 0.001, 4)
    knock = env(lowpass(noise(0.06, rng), 0.3 * p), 0.0005, 4)
    return mix((thud, 0), (scale(knock, 0.8), 0))


def build_lash(rng, p):
    # Rope pulled tight around a beam: a squeaky fibre stretch, then a short creak.
    stretch = swell(lowpass(osc(0.35, lambda t: (480 + 220 * t) * p + 30 * math.sin(t * 160), "saw"), 0.12), 0.7)
    fibre = swell(highpass(noise(0.35, rng), 0.3), 0.6)
    return mix((scale(stretch, 0.5), 0), (scale(fibre, 0.3), 0), (scale(env(creak(0.2, p, 140), 0.01, 2), 0.6), 0.3))


def build_thatch(rng, p):
    # A pine bough laid on the roof: needles rustling, then a soft landing.
    land = env(lowpass(noise(0.1, rng), 0.08), 0.003, 3)
    return mix((scale(rustle(0.4, rng, 0.5 * p), 0.7), 0), (land, 0.3))


def build_stage_done(rng, p):
    # The new part takes the weight: a creak and a settling knock.
    knock = env(osc(0.15, lambda t: 140 * p), 0.001, 5)
    return mix((swell(creak(0.6, p), 0.4), 0), (scale(knock, 0.7), 0.55))


def build_complete(rng, p):
    # Whole structure settles: long creak, a heavy thud, boughs shifting on the roof.
    thud = env(osc(0.4, lambda t: 70 * p * (1 - 0.3 * t)), 0.002, 3)
    return mix((swell(creak(1.1, p, 80), 0.5), 0), (thud, 0.9),
               (scale(env(lowpass(noise(0.3, rng), 0.1), 0.003, 2), 0.6), 0.9),
               (scale(rustle(0.6, rng, 0.4 * p), 0.5), 1.05))


# event_id -> (recipe, number of variations)
RECIPES = {
    "footstep": (footstep, 4), "axe_swing": (axe_swing, 3), "axe_hit_wood": (axe_hit_wood, 3),
    "tree_fall": (tree_fall, 1), "player_hurt": (player_hurt, 3), "player_death": (player_death, 1),
    "eat": (eat, 2), "pickup_wood": (pickup_wood, 2), "pickup_meat": (pickup_meat, 2),
    "pickup_cooked_meat": (pickup_cooked_meat, 2), "spit_place": (spit_place, 2),
    "spit_sizzle_loop": (spit_sizzle_loop, 1), "spit_done": (spit_done, 1),
    "mortar_place": (mortar_place, 2), "mortar_grind_loop": (mortar_grind_loop, 1), "mortar_done": (mortar_done, 1),
    "build_saw_loop": (build_saw_loop, 1), "build_stake_drive": (build_stake_drive, 3), "build_lash": (build_lash, 3),
    "build_thatch": (build_thatch, 3), "build_stage_done": (build_stage_done, 2), "build_complete": (build_complete, 1),
    "herb_yarrow_pick": (herb_yarrow_pick, 3), "herb_angelica_pick": (herb_angelica_pick, 3),
    "herb_wolfsbane_pick": (herb_wolfsbane_pick, 2), "herb_yarrow_use": (herb_yarrow_use, 2),
    "herb_angelica_use": (herb_angelica_use, 2), "herb_wolfsbane_use": (herb_wolfsbane_use, 1),
    "herb_wolfsbane_wear_off": (herb_wolfsbane_wear_off, 1),
    "wolf_growl": (wolf_growl, 2), "wolf_howl": (wolf_howl, 2), "wolf_bite": (wolf_bite, 2),
    "wolf_hurt": (wolf_hurt, 2), "wolf_death": (wolf_death, 1), "campfire_ignite": (campfire_ignite, 1),
    "campfire_add_wood": (campfire_add_wood, 2), "campfire_extinguish": (campfire_extinguish, 1),
    "campfire_loop": (campfire_loop, 1), "war_horn": (war_horn, 1), "ambience_wind": (ambience_wind, 1),
    "ui_click": (ui_click, 1), "ui_hover": (ui_hover, 1),
    "ui_inventory_open": (ui_inventory_open, 1), "ui_inventory_close": (ui_inventory_close, 1),
}


def write_wav(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    frames = b"".join(struct.pack("<h", int(s / peak * 0.8 * 32767)) for s in samples)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(frames)


def clean():
    removed = 0
    for path in EVENTS_DIR.glob("*/placeholder_*.wav*"):  # also catches .wav.import
        path.unlink()
        removed += 1
    print(f"removed {removed} placeholder files")


def main():
    if "--clean" in sys.argv:
        clean()
        return
    for event_id, (recipe, variations) in RECIPES.items():
        folder = EVENTS_DIR / event_id
        folder.mkdir(parents=True, exist_ok=True)
        for v in range(variations):
            rng = random.Random(zlib.crc32(event_id.encode()) + v)
            pitch = 1.0 + (v - (variations - 1) / 2) * 0.08
            write_wav(folder / f"placeholder_{v + 1}.wav", recipe(rng, pitch))
        print(f"{event_id}: {variations}")


if __name__ == "__main__":
    main()
