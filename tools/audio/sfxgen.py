#!/usr/bin/env python3
"""Synthesizes the prototype sound effects into assets/sfx/*.wav.

Small sfxr-style recipes: oscillators with pitch slides, filtered noise and
envelopes. Deterministic (fixed seed), so re-running gives identical files.
Usage: python3 tools/audio/sfxgen.py
"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "sfx"
rng = np.random.default_rng(1987)


def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def slide(f0, f1, dur, curve=1.0):
    t = t_axis(dur)
    k = (t / dur) ** curve
    return f0 + (f1 - f0) * k


def osc(freqs, shape="square", duty=0.5):
    phase = np.cumsum(freqs) / RATE % 1.0
    if shape == "square":
        return np.where(phase < duty, 1.0, -1.0)
    if shape == "tri":
        return 4.0 * np.abs(phase - 0.5) - 1.0
    if shape == "saw":
        return 2.0 * phase - 1.0
    return np.sin(2 * np.pi * phase)


def noise(dur):
    return rng.uniform(-1, 1, int(RATE * dur))


def lowpass(x, cutoff):
    # One-pole filter; cutoff may be an array to sweep.
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, attack=0.005, decay_pow=1.5):
    t = np.linspace(0, 1, n)
    a = max(1, int(RATE * attack))
    e = (1 - t) ** decay_pow
    e[:a] *= np.linspace(0, 1, a)
    return e


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def main():
    d = 0.11
    save("jump", lowpass(osc(slide(260, 520, d, 0.6), "square", 0.25), 5000) * env(int(RATE * d)), 0.55)

    d = 0.2
    whoosh = highpass(noise(d), 1500) * env(int(RATE * d), 0.03, 2.0) * 0.5
    chirp = osc(slide(520, 1040, d, 0.5), "tri") * env(int(RATE * d), 0.002, 2.5)
    save("double_jump", mix(chirp, whoosh), 0.6)

    d = 0.12
    click = highpass(noise(0.03), 2000) * env(int(RATE * 0.03))
    tone = osc(slide(330, 560, d, 0.5), "square", 0.3) * env(int(RATE * d))
    save("wall_jump", mix(lowpass(tone, 4000), click * 0.6), 0.55)

    d = 0.1
    save("land", lowpass(noise(d), slide(1200, 200, d)) * env(int(RATE * d), 0.001, 2.0), 0.7)

    d = 0.06
    save("step", lowpass(noise(d), 900) * env(int(RATE * d), 0.001, 3.0), 0.5)

    d = 0.2
    save("dash", lowpass(highpass(noise(d), 400), slide(800, 5000, d, 0.5)) * env(int(RATE * d), 0.01, 1.2), 0.7)

    d = 0.1
    save("slash", highpass(lowpass(noise(d), slide(7000, 1500, d)), 800) * env(int(RATE * d), 0.004, 1.5), 0.6)

    d = 0.09
    body = osc(slide(180, 70, d), "square", 0.4) * env(int(RATE * d), 0.001, 1.2)
    crunch = lowpass(noise(d), 3000) * env(int(RATE * d), 0.001, 3.0)
    # The two loudest cues sit a few dB under their old file level so the mix
    # check keeps headroom (pass 270); Sfx.LIFT plays them back as loud as before.
    save("hit", mix(lowpass(body, 2500), crunch * 0.8), 0.62)

    d = 0.12
    save("pogo", mix(osc(slide(620, 940, d, 0.3), "tri") * env(int(RATE * d), 0.001, 2.0),
                     highpass(noise(0.03), 3000) * env(int(RATE * 0.03)) * 0.4), 0.6)

    d = 0.08
    save("thorn", lowpass(osc(slide(300, 200, d), "square", 0.2), 2000) * env(int(RATE * d)), 0.5)

    d = 0.35
    rumble = lowpass(noise(d), slide(1500, 150, d)) * env(int(RATE * d), 0.002, 1.3)
    save("break", mix(rumble, lowpass(osc(slide(120, 50, d), "square"), 800) * env(int(RATE * d)) * 0.5), 0.85)

    # Lithic Fracture (pass 497): a deep grinding groan as the floor splits.
    d = 0.3
    grind = lowpass(noise(d), slide(900, 120, d)) * env(int(RATE * d), 0.008, 1.1)
    groan = osc(slide(90, 150, d, 0.5), "square", 0.35) * env(int(RATE * d), 0.01, 1.3) * 0.6
    save("lithic_cast", mix(grind, lowpass(groan, 1200)), 0.7)

    # Each stone column's crack as it thrusts up.
    d = 0.1
    knock = osc(slide(150, 60, d), "square", 0.4) * env(int(RATE * d), 0.001, 1.4)
    crack = lowpass(noise(d), slide(3500, 400, d)) * env(int(RATE * d), 0.001, 2.2)
    save("lithic_hit", mix(lowpass(knock, 2000), crack * 0.7), 0.6)

    d = 0.14
    body = lowpass(osc(slide(140, 55, d), "square", 0.45), 2000) * env(int(RATE * d), 0.001, 1.0)
    swish = highpass(lowpass(noise(d), slide(6000, 900, d)), 500) * env(int(RATE * d), 0.004, 1.2)
    save("heavy", mix(swish, body * 0.7), 0.75)

    d = 0.3
    ring = mix(osc(slide(1320, 1250, d), "sine") * env(int(RATE * d), 0.001, 2.2),
               osc(slide(1980, 1900, d), "sine") * env(int(RATE * d), 0.001, 3.0) * 0.5)
    save("parry", mix(ring, highpass(noise(0.04), 3000) * env(int(RATE * 0.04)) * 0.8), 0.7)

    d = 0.12
    save("guard", mix(lowpass(osc(slide(420, 380, d), "square", 0.3), 2500) * env(int(RATE * d), 0.001, 2.0),
                      lowpass(noise(d), 2500) * env(int(RATE * d), 0.001, 3.0) * 0.6), 0.6)

    # A guard that can't be paid for breaks (pass 242): the guard's knock cut
    # short by a dry crack of splitting wood and a dull drop under it, so a
    # failed block never sounds like a held one.
    d = 0.28
    crack = highpass(noise(0.05), 1800) * env(int(RATE * 0.05), 0.0005, 1.0)
    crack = np.concatenate([crack, np.zeros(int(RATE * d) - len(crack))])
    knock = lowpass(osc(slide(330, 150, d), "square", 0.3), 1800) * env(int(RATE * d), 0.001, 2.4)
    splinter = lowpass(highpass(noise(d), 700), 3200) * env(int(RATE * d), 0.002, 3.2) * 0.5
    save("guard_break", mix(crack, knock * 0.8, splinter), 0.6)

    d = 0.12
    save("coin", mix(osc(np.where(t_axis(d) < 0.04, 1320.0, 1760.0), "square", 0.5) * env(int(RATE * d), 0.001, 1.5)), 0.4)

    # A 25 or 100 g coin (pass 206): the same two notes a fourth lower, a third
    # note above, and a bell tail, so a big coin sounds weightier than a small one.
    d = 0.3
    ta = t_axis(d)
    notes = np.where(ta < 0.04, 990.0, np.where(ta < 0.08, 1320.0, 1980.0))
    bell = osc(np.full_like(ta, 1980.0), "sine") * env(int(RATE * d), 0.001, 2.5) * np.where(ta < 0.08, 0.0, 0.6)
    save("coin_big", mix(osc(notes, "square", 0.5) * env(int(RATE * d), 0.001, 2.2), bell), 0.5)

    d = 0.25
    bubble = osc(slide(300, 900, d, 0.4) + 80 * np.sin(2 * np.pi * 30 * t_axis(d)), "sine") * env(int(RATE * d), 0.01, 1.2)
    save("cast", mix(bubble, lowpass(noise(d), 1800) * env(int(RATE * d), 0.02, 1.0) * 0.4), 0.6)

    d = 0.2
    save("splash", lowpass(highpass(noise(d), 600), slide(5000, 1200, d)) * env(int(RATE * d), 0.002, 1.6), 0.6)

    d = 0.3
    pop = lowpass(osc(slide(240, 60, d, 0.5), "square", 0.5), 1800) * env(int(RATE * d), 0.001, 1.3)
    save("enemy_die", mix(pop, lowpass(noise(d), slide(3000, 300, d)) * env(int(RATE * d), 0.001, 1.6)), 0.75)

    d = 0.4
    buzz = osc(np.full(int(RATE * d), 170.0) + 12 * np.sin(2 * np.pi * 9 * t_axis(d)), "saw")
    save("buzz", lowpass(buzz, 1400) * env(int(RATE * d), 0.05, 0.6), 0.45)

    d = 0.5
    sparkle = sum(osc(np.full(int(RATE * d), f), "sine") * env(int(RATE * d), 0.002 + i * 0.05, 2.0)
                  for i, f in enumerate([880, 1108, 1318, 1760]))
    save("heal", sparkle, 0.5)

    d = 0.3
    save("drink", lowpass(noise(d), 700 + 400 * np.sin(2 * np.pi * 8 * t_axis(d)) ** 2) * env(int(RATE * d), 0.02, 0.8), 0.45)

    d = 0.9
    save("death", lowpass(osc(slide(330, 55, d, 0.6), "square", 0.5), slide(3000, 400, d)) * env(int(RATE * d), 0.005, 0.9), 0.4)

    d = 0.12
    save("fizzle", highpass(lowpass(noise(d), 2500), 800) * env(int(RATE * d), 0.002, 2.0), 0.35)

    d = 0.1
    save("hop", lowpass(osc(slide(180, 320, d), "square", 0.4), 2000) * env(int(RATE * d)), 0.45)

    d = 0.25
    save("hurt", lowpass(osc(slide(420, 140, d, 0.7), "square", 0.5), 3000) * env(int(RATE * d), 0.002, 1.0), 0.42)
    # A blow that costs a whole mask or more (pass 198): a low body thud and a
    # crunch of grit under the hurt yelp, so a deep zone's heavy hit reads by ear.
    d = 0.32
    save("hurt_heavy", mix(
        lowpass(osc(slide(110, 45, d, 0.6), "sine"), 400) * env(int(RATE * d), 0.002, 1.2),
        lowpass(noise(d), 1400) * env(int(RATE * d), 0.001, 3.0) * 0.6,
    ), 0.7)


    # --- World and UI (M3) ---
    def arpeggio(notes, step, shape="square", duty=0.5, tail=0.25):
        dur = step * len(notes) + tail
        n = int(RATE * dur)
        out = np.zeros(n)
        for i, f in enumerate(notes):
            start = int(RATE * i * step)
            seg = n - start
            out[start:] += osc(np.full(seg, float(f)), shape, duty) * env(seg, 0.002, 2.2)
        return out

    save("item", lowpass(arpeggio([523, 659, 784, 1047, 1319], 0.07, "square", 0.25, 0.5), 5000), 0.5)
    save("secret", lowpass(arpeggio([392, 494, 587, 740, 988], 0.06, "tri", 0.5, 0.4), 6000), 0.55)
    save("save", arpeggio([523, 784, 1047, 1568], 0.09, "sine", 0.5, 0.7), 0.5)

    d = 0.3
    creak = lowpass(osc(slide(90, 70, d) + 6 * np.sin(2 * np.pi * 23 * t_axis(d)), "saw"), 900) * env(int(RATE * d), 0.03, 1.2)
    save("door", mix(creak, lowpass(noise(d), 600) * env(int(RATE * d), 0.01, 2.0) * 0.5), 0.55)

    d = 0.35
    thunk = lowpass(osc(slide(160, 90, 0.12), "square", 0.4), 1500) * env(int(RATE * 0.12), 0.001, 1.5)
    save("chest", mix(thunk, np.concatenate([np.zeros(int(RATE * 0.1)), arpeggio([784, 1047, 1319], 0.05, "square", 0.5, 0.1) * 0.5])), 0.55)

    save("rank", lowpass(arpeggio([392, 523, 659, 784, 1047, 784, 1047], 0.08, "square", 0.5, 0.6), 4500), 0.5)

    # --- Bosses (M3) ---
    d = 1.3
    growl = osc(slide(95, 48, d, 0.8) + 9 * np.sin(2 * np.pi * 31 * t_axis(d)), "saw")
    rasp = lowpass(noise(d), 900 + 500 * np.sin(2 * np.pi * 4 * t_axis(d)) ** 2)
    save("roar", mix(lowpass(growl, 1100), rasp * 0.7) * env(int(RATE * d), 0.08, 0.7), 0.8)

    d = 0.9
    save("rumble", lowpass(noise(d), 180) * env(int(RATE * d), 0.15, 0.6) * 3.0, 0.7)

    d = 0.22
    save("splat", lowpass(noise(d), slide(2400, 300, d)) * env(int(RATE * d), 0.002, 1.8), 0.6)

    d = 0.5
    grains = noise(d) * (np.random.default_rng(7).random(int(RATE * d)) > 0.9)
    save("crumble", mix(lowpass(grains, 2500), lowpass(noise(d), 300) * 0.8) * env(int(RATE * d), 0.003, 1.2), 0.7)

    d = 0.03
    save("blip", lowpass(osc(np.full(int(RATE * d), 880.0), "square", 0.5), 3000) * env(int(RATE * d), 0.001, 1.0), 0.3)

    # A gear spinning up: a ratcheting saw that climbs in pitch and clicks faster.
    d = 0.5
    t = t_axis(d)
    ratchet = (np.sin(2 * np.pi * np.cumsum(slide(14, 60, d)) / RATE) > 0.6).astype(float)
    spin = osc(slide(140, 620, d, 0.7), "saw") * (0.5 + 0.5 * ratchet)
    save("whir", lowpass(spin, slide(900, 3200, d)) * np.minimum(1.0, t / 0.35), 0.4)


    # The Ringreader names your title: a short heraldic fanfare, square lead over a
    # triangle bass, ending on a held major chord (Yldenfall's rank-up jingle).
    beat = 0.11
    lead = [(523, 1), (523, 1), (523, 1), (659, 3), (587, 1), (659, 1), (784, 6)]
    bass = [(131, 3), (165, 3), (196, 6)]
    def line(notes, shape, duty, decay):
        n = int(RATE * beat * sum(b for _, b in notes)) + int(RATE * 0.5)
        out = np.zeros(n)
        pos = 0
        for f, b in notes:
            seg = n - pos
            out[pos:] += osc(np.full(seg, float(f)), shape, duty) * env(seg, 0.004, decay) * (1.0 if b < 6 else 1.3)
            pos += int(RATE * beat * b)
        return out
    a = line(lead, "square", 0.25, 1.6)
    b = line(bass, "tri", 0.5, 0.9)
    m = max(len(a), len(b))
    a = np.pad(a, (0, m - len(a)))
    b = np.pad(b, (0, m - len(b)))
    chord_start = int(RATE * beat * 9)
    chord = np.zeros(m)
    seg = m - chord_start
    for f in (392, 523, 659):
        chord[chord_start:] += osc(np.full(seg, float(f)), "square", 0.5) * env(seg, 0.01, 1.2) * 0.3
    save("title", lowpass(mix(a, b * 0.8, chord), 5000), 0.55)

    # The Kettleforge smith's hammer on the anvil: a bright, inharmonic ring.
    d = 0.5
    partials = [(880, 1.0, 2.0), (2380, 0.5, 3.0), (3960, 0.3, 4.0), (5470, 0.15, 5.0)]
    ring = mix(*[osc(np.full(int(RATE * d), float(f)), "sine") * env(int(RATE * d), 0.001, k) * g for f, g, k in partials])
    tick = highpass(noise(0.02), 2500) * env(int(RATE * 0.02), 0.0005) * 0.9
    save("anvil", mix(ring, tick), 0.5)

    # The Minecart Rider's brake: iron on iron, a wavering high shriek.
    d = 0.22
    n = int(RATE * d)
    wobble = 1900 + 120 * np.sin(np.linspace(0, 2 * np.pi * 9, n))
    screech = mix(osc(wobble, "square", 0.2) * 0.5, osc(wobble * 1.51, "sine") * 0.4)
    grit = highpass(noise(d), 3000) * 0.5
    save("brake", lowpass(mix(screech, grit), 7000) * env(n, 0.01, 0.8), 0.4)

    # A cart wheel over a rail joint: two quick clacks and a rumble.
    d = 0.14
    n = int(RATE * d)
    clack = np.zeros(n)
    for start in (0, int(RATE * 0.05)):
        k = int(RATE * 0.025)
        clack[start:start + k] += lowpass(noise(0.025), 1800)[:k] * env(k, 0.0005, 2.5)
    rumble = lowpass(osc(np.full(n, 70.0), "square", 0.5), 400) * env(n, 0.005, 1.0) * 0.5
    save("cart", mix(clack, rumble), 0.6)

    # Footsteps per surface (design bible 11): the player plays step_<surface> for
    # the ground underfoot. Each is short, quiet and differs in body and grain.
    d = 0.07
    n = int(RATE * d)
    grit = highpass(noise(d), 2500) * env(n, 0.0005, 4.0) * 0.6
    thump = lowpass(noise(d), 700) * env(n, 0.001, 2.5)
    save("step_stone", mix(thump, grit), 0.5)

    d = 0.09
    n = int(RATE * d)
    save("step_moss", lowpass(noise(d), slide(700, 250, d)) * env(n, 0.012, 2.0), 0.45)

    d = 0.09
    n = int(RATE * d)
    knock = osc(slide(210, 150, d), "tri") * env(n, 0.001, 3.0)
    scuff = lowpass(noise(d), 1600) * env(n, 0.001, 4.0) * 0.5
    save("step_plank", mix(knock, scuff), 0.5)

    d = 0.12
    n = int(RATE * d)
    ring = mix(osc(np.full(n, 1180.0), "sine"), osc(np.full(n, 1730.0), "sine") * 0.6,
               osc(np.full(n, 2610.0), "sine") * 0.3) * env(n, 0.0005, 3.5) * 0.35
    clank = lowpass(noise(0.03), 2200) * env(int(RATE * 0.03), 0.0005, 2.5)
    save("step_iron", mix(clank, ring), 0.45)

    d = 0.12
    n = int(RATE * d)
    save("step_sap", lowpass(noise(d), slide(250, 1400, d, 0.7)) * env(n, 0.02, 1.5), 0.45)

    # A Lantern Ghost's wail before it lunges: a breathy falling moan with a
    # wavering second voice.
    d = 0.55
    n = int(RATE * d)
    vib = 1 + 0.03 * np.sin(2 * np.pi * 6 * t_axis(d))
    moan = osc(slide(620, 380, d, 0.8) * vib, "sine") + osc(slide(930, 560, d, 0.8) * vib * 1.01, "tri") * 0.3
    breath = lowpass(highpass(noise(d), 900), 3000) * 0.35
    save("wail", mix(moan, breath) * env(n, 0.12, 1.2), 0.45)

    # Gloamweaver (bible 8.3). A web strand shot from the vault: an elastic zip
    # that rises and snaps tight.
    d = 0.28
    n = int(RATE * d)
    zip_ = osc(slide(300, 1800, d, 0.4), "tri") * 0.5
    hiss = highpass(lowpass(noise(d), slide(2000, 7000, d, 0.5)), 1200) * 0.6
    save("web_shoot", mix(zip_, hiss) * env(n, 0.01, 1.6), 0.5)

    # The strand catching you: a wet, sticky slap with a low twang.
    d = 0.22
    n = int(RATE * d)
    slap = lowpass(noise(d), 1400) * env(n, 0.001, 3.0)
    twang = osc(slide(190, 150, d) * (1 + 0.04 * np.sin(2 * np.pi * 18 * t_axis(d))), "tri") * env(n, 0.002, 1.5) * 0.7
    save("web_catch", mix(slap, twang), 0.6)

    # Reeling in: the strand creaks under tension, a ratchet of ticks over a
    # rising strain.
    d = 0.9
    n = int(RATE * d)
    ticks = np.zeros(n)
    tick = highpass(noise(0.012), 1800) * env(int(RATE * 0.012), 0.0005, 2.0)
    for k in range(14):
        i = int(k / 14 * (n - len(tick)))
        ticks[i:i + len(tick)] += tick * (0.6 + 0.4 * (k % 2))
    strain = osc(slide(140, 260, d, 0.7), "saw") * 0.18
    save("reel", mix(ticks, lowpass(strain, 900)) * env(n, 0.03, 0.6), 0.5)

    # Many legs on stone: a quick patter of dry clicks, for her climb and the
    # shiver before she drops.
    d = 0.45
    n = int(RATE * d)
    rng = np.random.default_rng(83)
    pat = np.zeros(n)
    click = lowpass(highpass(noise(0.008), 1500), 6000) * env(int(RATE * 0.008), 0.0003, 2.0)
    for k in range(16):
        i = int((k + rng.uniform(-0.3, 0.3)) / 16 * (n - len(click)))
        i = max(0, min(n - len(click), i))
        pat[i:i + len(click)] += click * rng.uniform(0.5, 1.0)
    save("skitter", pat * env(n, 0.02, 0.8), 0.5)

    # A soul-lantern breaking: thin glass and a bright tinkle that rings away.
    d = 0.5
    n = int(RATE * d)
    crack = highpass(noise(0.04), 3000) * env(int(RATE * 0.04), 0.0005, 2.0)
    tinkle = mix(osc(np.full(n, 2350.0), "sine"), osc(np.full(n, 3120.0), "sine") * 0.7,
                 osc(np.full(n, 4410.0), "sine") * 0.4) * env(n, 0.001, 2.5) * 0.35
    save("lantern_break", mix(crack, tinkle), 0.5)

    # Bound fog parting before the Lantern Key: a breathy rising shimmer, like
    # a held breath let go, with a soft bell at its crest.
    d = 0.9
    n = int(RATE * d)
    breath = lowpass(highpass(noise(d), 500), slide(900, 4200, d, 0.6)) * 0.6
    shimmer = mix(osc(slide(660, 990, d, 0.5), "sine"), osc(slide(990, 1485, d, 0.5), "sine") * 0.5) * 0.25
    save("curtain", mix(breath, shimmer) * env(n, 0.25, 1.4), 0.5)

    # Striding through an elven veil: a quick airy rush through silk, with a
    # pair of high glassy notes a fifth apart that ring as you pass.
    d = 0.4
    n = int(RATE * d)
    rush = lowpass(highpass(noise(d), 900), slide(5200, 1800, d, 0.5)) * env(n, 0.01, 2.2) * 0.55
    ring = mix(osc(np.full(n, 1760.0), "sine"), osc(np.full(n, 2640.0), "sine") * 0.6) * env(n, 0.004, 2.0) * 0.22
    save("veil", mix(rush, ring), 0.5)


    # A Bog Puffcap swelling: a wet, rising creak, like a bladder filling.
    d = 0.55
    n = int(RATE * d)
    creak = lowpass(osc(slide(90, 210, d, 0.7), "square", 0.3), 900) * 0.5
    wet = lowpass(noise(d), slide(300, 1400, d, 0.8)) * 0.4
    save("swell", mix(creak, wet) * env(n, 0.3, 0.6), 0.45)

    # Its burst: a soft, dusty pop and a long hiss of spores settling.
    d = 0.8
    n = int(RATE * d)
    pop = lowpass(noise(0.06), 700) * env(int(RATE * 0.06), 0.001, 2.0)
    hiss = lowpass(highpass(noise(d), 1800), 6000) * env(n, 0.02, 1.6) * 0.5
    save("spore", mix(pop, hiss), 0.55)

    # A fire seal doused by Deluge: a sharp splash and a long hiss of steam.
    d = 0.9
    n = int(RATE * d)
    slap = lowpass(noise(0.05), 2500) * env(int(RATE * 0.05), 0.001, 2.0)
    steam = highpass(lowpass(noise(d), slide(7000, 2500, d, 0.7)), 1200) * env(n, 0.03, 1.2) * 0.6
    save("douse", mix(slap, steam), 0.55)

    # the Haar Wyrm's bite: a deep growl that snaps shut on a hard bone clack.
    d = 0.45
    n = int(RATE * d)
    growl = lowpass(osc(slide(70, 120, d, 0.5), "square", 0.4), 600) * env(n, 0.05, 1.2) * 0.6
    clack = highpass(noise(0.03), 1500) * env(int(RATE * 0.03), 0.0005, 2.5)
    save("hydra_bite", mix(growl, clack), 0.6)

    # A head bellowing steam: a pressurized steam-pipe hiss over a throaty
    # breath. Hotter and sharper than the old fog breath. These two steam sounds
    # draw from their own `hr` rng, and one discarded `noise(1.0)` keeps the
    # shared stream exactly where the old one-draw fog breath left it, so adding
    # them leaves every sound after this point byte-for-byte unchanged.
    noise(1.0)
    hr = np.random.default_rng(499)
    d = 1.1
    n = int(RATE * d)
    hiss = highpass(lowpass(hr.uniform(-1, 1, n), 6500), 2200) * 0.6
    exhale = lowpass(highpass(hr.uniform(-1, 1, n), 200), slide(2600, 900, d, 0.6)) * 0.4
    throat = lowpass(osc(np.full(n, 55.0), "square", 0.5), 300) * 0.22
    save("haar_breath", mix(hiss, exhale, throat) * env(n, 0.06, 1.0), 0.5)

    # Pressure building before the bellow (the breath tell): a rising steam hiss.
    d = 0.7
    n = int(RATE * d)
    rise = highpass(lowpass(hr.uniform(-1, 1, n), slide(3000, 7000, d, 0.7)), slide(1400, 3200, d)) * slide(0.15, 0.6, d)
    save("steam_hiss", rise * env(n, 0.2, 0.6), 0.4)

    # The coil bursting and the arena flooding: a rushing roar of water.
    d = 1.6
    n = int(RATE * d)
    rush = lowpass(noise(d), slide(500, 2600, d, 0.4)) * 0.8
    rumble = lowpass(noise(d), 160) * 0.8
    save("flood", mix(rush, rumble) * env(n, 0.2, 1.3), 0.6)

    # The hydra's roar (a phase change): three throats, a fifth apart, falling.
    d = 1.1
    n = int(RATE * d)
    roar = mix(*[lowpass(osc(slide(f, f * 0.7, d, 0.6), "saw" if i else "square", 0.3), 1400) * 0.4
                 for i, f in enumerate([98.0, 147.0, 196.0])])
    breath = lowpass(highpass(noise(d), 300), 2500) * 0.35
    save("hydra_roar", mix(roar, breath) * env(n, 0.08, 1.0), 0.65)

    # A bounce-pod throwing you up: a rubbery squelch and a rising, wobbling boing.
    d = 0.45
    n = int(RATE * d)
    squelch = lowpass(noise(0.05), 900) * env(int(RATE * 0.05), 0.001, 2.0)
    t = np.arange(n) / RATE
    boing = osc(slide(180, 520, d, 0.5) * (1 + 0.06 * np.sin(2 * np.pi * 22 * t)), "sine") * env(n, 0.005, 1.4) * 0.6
    save("pod", mix(squelch, boing), 0.55)

    # A Thunder Beetle charging: static crackling louder and faster over a rising buzz.
    d = 0.6
    n = int(RATE * d)
    t = np.arange(n) / RATE
    crackle = highpass(noise(d), 2500) * (np.random.default_rng(55).random(n) < (0.02 + 0.25 * t / d)) * 1.6
    buzz = lowpass(osc(slide(110, 240, d, 0.8), "saw"), 1800) * 0.25 * (t / d)
    save("static", mix(crackle, buzz) * env(n, 0.4, 0.4), 0.45)

    # Its discharge: a hard electric snap and a short sizzling tail.
    d = 0.5
    n = int(RATE * d)
    snap = highpass(noise(0.04), 900) * env(int(RATE * 0.04), 0.0005, 2.0) * 1.2
    sizzle = highpass(lowpass(noise(d), 7000), 1500) * (np.sign(np.sin(2 * np.pi * 60 * np.arange(n) / RATE)) * 0.5 + 0.5)
    hum = osc(np.full(n, 120.0), "square", 0.5) * 0.25
    save("zap", mix(snap, sizzle * 0.5 * env(n, 0.005, 1.6), hum * env(n, 0.005, 2.5)), 0.6)

    # The core's beam striking (pass 244): the zap marks the line, this is the
    # lance itself. A bright whoomph of light tearing open, a searing high whine
    # that falls as it burns out over the beam's 0.35 s, and a low thrum under it.
    d = 0.42
    n = int(RATE * d)
    whoomph = lowpass(noise(0.08), 2400) * env(int(RATE * 0.08), 0.002, 1.4)
    whoomph = np.concatenate([whoomph, np.zeros(n - len(whoomph))])
    whine = osc(slide(2600, 1400, d), "sine") * env(n, 0.004, 1.8) * 0.6
    sear = highpass(lowpass(noise(d), 9000), 2500) * env(n, 0.003, 1.5) * 0.45
    thrum = osc(slide(90, 70, d), "square", 0.4) * env(n, 0.004, 2.2) * 0.3
    save("core_beam", mix(whoomph, whine, sear, thrum), 0.55)

    # A Crystal Dwarf's spike stabbing up through the floor (pass 246): a dry
    # crack of stone giving way and a hard glassy ping with out-of-tune partials,
    # short, so the six of an eruption tick along the floor toward you.
    d = 0.24
    n = int(RATE * d)
    crack = highpass(noise(0.03), 1800) * env(int(RATE * 0.03), 0.0005, 2.2)
    crack = np.concatenate([crack, np.zeros(n - len(crack))])
    ping = (osc(np.full(n, 2093.0), "sine") + 0.55 * osc(np.full(n, 3311.0), "sine") + 0.3 * osc(np.full(n, 4870.0), "sine")) * env(n, 0.001, 3.0) * 0.5
    grind = lowpass(noise(d), 900) * env(n, 0.002, 4.0) * 0.35
    save("crystal_stab", mix(crack, ping, grind), 0.5)

    # A fireball bursting: a soft whump and a spray of crackling embers.
    d = 0.55
    n = int(RATE * d)
    whump = lowpass(noise(d), slide(1800, 200, d, 0.5)) * env(n, 0.003, 1.8) * 1.1
    pops = highpass(noise(d), 3000) * (np.random.default_rng(57).random(n) < 0.03) * env(n, 0.01, 1.2) * 1.4
    thud = osc(slide(110, 50, d, 0.7), "sine") * env(n, 0.002, 2.2) * 0.5
    save("fire_burst", mix(whump, pops, thud), 0.6)

    # A Wisplight orb striking: a glassy two-note chime over a soft breathy puff.
    d = 0.45
    n = int(RATE * d)
    chime = (osc(np.full(n, 1318.0), "sine") + osc(np.full(n, 1976.0), "sine") * 0.6) * env(n, 0.002, 2.4) * 0.5
    puff = lowpass(noise(d), slide(4000, 600, d, 0.6)) * env(n, 0.004, 2.0) * 0.5
    save("wisplight_hit", mix(chime, puff), 0.55)

    # A boss crossing into its next phase: a deep impact, a reversed swell and a
    # bright ringing fifth over it, so the moment lands even under the music.
    d = 1.4
    n = int(RATE * d)
    t = np.arange(n) / RATE
    boom = osc(slide(70, 34, d, 0.5), "sine") * env(n, 0.002, 2.2) * 1.2
    crack = highpass(noise(0.12), 1200) * env(int(RATE * 0.12), 0.001, 2.5) * 0.8
    swell = lowpass(noise(d), slide(300, 5000, d, 0.4)) * np.clip(t / 0.35, 0, 1) * np.exp(-np.maximum(t - 0.35, 0) * 5) * 0.35
    ring = (osc(np.full(n, 440.0), "sine") + osc(np.full(n, 659.3), "sine") * 0.7 + osc(np.full(n, 880.0), "sine") * 0.4) * env(n, 0.01, 1.4) * 0.3
    save("phase_break", mix(boom, crack, swell, ring), 0.75)

    # A stride seed bursting: a quick upward airy sweep and a bright pluck.
    d = 0.35
    n = int(RATE * d)
    sweep = highpass(lowpass(noise(d), slide(1500, 7000, d, 0.5)), 600) * env(n, 0.01, 2.0) * 0.6
    rise = slide(880, 1760, 0.08, 0.5)
    pluck = osc(np.concatenate([rise, np.full(n - len(rise), 1760.0)]), "sine")
    save("seed", mix(sweep, pluck * env(n, 0.002, 3.0) * 0.7), 0.55)

    # Feather Fall opening: a soft cloth-and-air whoosh, rising then settling.
    d = 0.35
    n = int(RATE * d)
    whoosh = highpass(lowpass(noise(d), slide(900, 2600, d, 0.6)), 300) * env(n, 0.06, 1.4)
    save("glide", whoosh, 0.35)

    # A wall slide (pass 238): the glove's leather dragging down bark and stone,
    # a short rough rasp with a gritty flutter, quiet under a beat of repeats.
    d = 0.22
    n = int(RATE * d)
    t = np.arange(n) / RATE
    grit = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 37 * t)) * (0.7 + 0.3 * np.random.default_rng(238).random(n))
    rasp = highpass(lowpass(noise(d), slide(2600, 1500, d)), 500) * grit * env(n, 0.02, 1.2)
    save("wall_slide", rasp, 0.4)

    # Low health: a muffled double heartbeat, lub then dub.
    d = 0.42
    n = int(RATE * d)
    def thump(f0, at, amp):
        m = int(RATE * 0.16)
        x = lowpass(osc(slide(f0, f0 * 0.55, 0.16), "sine"), 400) * env(m, 0.004, 2.2) * amp
        out = np.zeros(n)
        i = int(RATE * at)
        out[i:i + m] = x[:n - i]
        return out
    save("heartbeat", thump(95, 0.0, 1.0) + thump(80, 0.2, 0.7), 0.5)

    # Dry bramble catching: a rush of flame and quick snapping twigs.
    d = 0.7
    n = int(RATE * d)
    rush = lowpass(highpass(noise(d), 400), 3000) * env(n, 0.08, 1.2) * 0.7
    snaps = highpass(noise(d), 2000) * (np.random.default_rng(58).random(n) < 0.05) * 1.5 * env(n, 0.02, 0.8)
    save("crackle", mix(rush, snaps), 0.5)

    # A conduit waking: a rising electric whine that settles into a steady hum.
    d = 0.8
    n = int(RATE * d)
    whine = lowpass(osc(slide(180, 720, d, 0.35), "saw"), 2400) * env(n, 0.01, 1.4) * 0.5
    hum = osc(np.full(n, 120.0), "square", 0.3) * 0.2 * (1 - env(n, 0.3, 1.0))
    crack = highpass(noise(0.05), 1500) * env(int(RATE * 0.05), 0.0005, 2.0)
    save("spark_up", mix(crack, whine, hum), 0.55)

    # A Storm Harpy rearing back: a raw, rising screech with a raspy edge.
    d = 0.5
    n = int(RATE * d)
    t = np.arange(n) / RATE
    cry = osc(slide(900, 1700, d, 0.6) * (1 + 0.03 * np.sin(2 * np.pi * 31 * t)), "saw") * 0.35
    rasp = highpass(lowpass(noise(d), 5000), 1800) * 0.4
    save("screech", lowpass(mix(cry, rasp), 4200) * env(n, 0.06, 1.2), 0.45)

    # Her feathers flung: three quick whips of air.
    d = 0.35
    n = int(RATE * d)
    whip = np.zeros(n)
    for k in range(3):
        m = int(RATE * 0.09)
        start = int(RATE * 0.06 * k)
        part = highpass(lowpass(noise(0.09), slide(5000, 1500, 0.09, 0.5)), 900) * env(m, 0.002, 2.0)
        whip[start:start + m] += part[: n - start]
    save("feather", whip, 0.5)

    # The Stillstone turned: a deep clock tick, a reversed shimmer drawn in, and
    # a glassy chime that hangs while time holds.
    d = 1.1
    n = int(RATE * d)
    t = np.arange(n) / RATE
    tick = highpass(noise(0.03), 1800) * env(int(RATE * 0.03), 0.0005, 2.5) * 1.2
    swell = highpass(noise(0.45), 3000) * np.linspace(0, 1, int(RATE * 0.45)) ** 2 * 0.4
    chime = (osc(np.full(n, 1318.5), "sine") + 0.5 * osc(np.full(n, 1975.5), "sine") + 0.3 * osc(np.full(n, 659.25), "sine")) * 0.3
    chime = chime * np.clip((t - 0.42) * 30, 0, 1) * np.exp(-np.maximum(t - 0.42, 0) * 3.0)
    out = np.zeros(n)
    out[: len(tick)] += tick
    out[: len(swell)] += swell
    out += chime
    save("stillstone", out, 0.5)

    # The glass running out (pass 230): a dry clock tick for each of its last
    # quarter-seconds, so you hear when stopped time is about to end.
    d = 0.08
    n = int(RATE * d)
    tick = highpass(noise(d), 2400) * env(n, 0.0005, 3.0) * 1.1
    tock = osc(np.full(n, 1760.0), "sine") * env(n, 0.001, 4.0) * 0.35
    save("glass_tick", tick + tock, 0.45)

    # Time running again (pass 230): the turned glass's shimmer let go forward,
    # a rush of air and a low clock thunk as the world starts up.
    d = 0.6
    n = int(RATE * d)
    rush = highpass(lowpass(noise(d), slide(1500, 6000, d, 0.6)), 600) * env(n, 0.02, 1.4) * 0.6
    thunk = lowpass(osc(slide(180, 90, 0.2, 0.8), "sine"), 400) * env(int(RATE * 0.2), 0.001, 2.5)
    out = rush.copy()
    out[: len(thunk)] += thunk
    save("glass_end", out, 0.5)

    # A ward turning sorcery (pass 230, bible 5.2): a bright glassy ring under
    # the hurt, so you hear your shield and helmet take part of a hex.
    d = 0.4
    n = int(RATE * d)
    t = np.arange(n) / RATE
    ring = (osc(np.full(n, 2093.0), "sine") + 0.6 * osc(np.full(n, 3136.0), "sine") + 0.4 * osc(np.full(n, 1046.5), "sine")) * np.exp(-t * 9.0) * 0.35
    sparkle = highpass(noise(0.05), 5000) * env(int(RATE * 0.05), 0.001, 2.0) * 0.5
    ring[: len(sparkle)] += sparkle
    save("ward", ring, 0.45)

    # A Clockwork Hound winding up: a ratchet clicking faster and faster under
    # a tightening spring whine.
    d = 0.5
    n = int(RATE * d)
    clicks = np.zeros(n)
    tt = 0.0
    gap = 0.07
    while tt < d - 0.01:
        start = int(RATE * tt)
        m = int(RATE * 0.008)
        part = highpass(noise(0.008), 2500) * env(m, 0.0003, 3.0)
        clicks[start:start + m] += part[: n - start]
        tt += gap
        gap = max(0.022, gap * 0.85)
    whine = lowpass(osc(slide(300, 900, d, 0.6), "saw"), 1800) * env(n, 0.15, 1.0) * 0.18
    save("ratchet", mix(clicks, whine), 0.5)

    # A swim stroke: a soft muffled whoosh with a couple of bubbles rising.
    d = 0.32
    n = int(RATE * d)
    whoosh = lowpass(noise(d), slide(300, 1200, d, 0.5)) * env(n, 0.04, 1.4) * 0.7
    bub = osc(slide(380, 900, d, 0.7), "sine") * np.exp(-np.arange(n) / RATE * 14.0) * 0.25
    save("swim", mix(whoosh, bub), 0.45)

    # Breaking the surface: a bright slap of spray over a low plunge.
    d = 0.5
    n = int(RATE * d)
    spray = highpass(noise(d), 1500) * env(n, 0.002, 2.2) * 0.7
    plunge = lowpass(noise(d), slide(900, 200, d, 0.5)) * env(n, 0.01, 1.5) * 0.8
    save("dive", mix(spray, plunge), 0.55)

    # A Spring Eel lunging: a wet hiss sliding up into a snap.
    d = 0.35
    n = int(RATE * d)
    hiss = lowpass(highpass(noise(d), 800), slide(1200, 4000, d, 0.6)) * env(n, 0.03, 1.2) * 0.6
    snap = highpass(noise(0.03), 2000) * env(int(RATE * 0.03), 0.0005, 3.0)
    out = hiss.copy()
    out[-len(snap):] += snap
    save("eel_lunge", out, 0.5)

    # Attack telegraphs and strikes (pass 102). Each tell rises so it reads as
    # "about to happen"; the whoosh is the fast strike that follows a lunge.
    # A blade being drawn back: a thin metal scrape climbing in pitch.
    d = 0.32
    n = int(RATE * d)
    ring = osc(slide(900, 1700, d, 0.8), "saw") * env(n, 0.2, 0.8) * 0.25
    scrape = lowpass(highpass(noise(d), 2500), slide(3000, 7000, d)) * env(n, 0.25, 0.7) * 0.6
    save("tell_blade", lowpass(mix(ring, scrape), 6000), 0.4)

    # A heavy body gathering itself: a low groan swelling up from the floor.
    d = 0.45
    n = int(RATE * d)
    groan = lowpass(osc(slide(55, 95, d, 0.7), "saw"), slide(200, 700, d)) * env(n, 0.35, 0.5)
    grit = lowpass(noise(d), slide(150, 600, d)) * env(n, 0.3, 0.6) * 0.5
    save("tell_heavy", mix(groan, grit), 0.6)

    # Power drawn in for a shot: a hum with a wobble rising to a high whine.
    d = 0.4
    n = int(RATE * d)
    wob = 1.0 + 0.04 * np.sin(2 * np.pi * 18 * t_axis(d))
    hum = osc(slide(220, 880, d, 1.4) * wob, "tri") * env(n, 0.3, 0.6) * 0.6
    air = highpass(noise(d), 4000) * env(n, 0.35, 0.5) * 0.15
    save("tell_charge", mix(hum, air), 0.42)

    # A body cutting through the air on a swoop or lunge.
    d = 0.24
    n = int(RATE * d)
    rush = lowpass(highpass(noise(d), 300), slide(900, 3500, d, 0.4)) * env(n, 0.06, 1.6)
    save("whoosh", rush, 0.55)

    # Voices of their own for the foes built after pass 102 (pass 112). Each tell
    # still rises toward the strike, but in the foe's own material.
    # Bark Knight bracing: living wood under strain, a stick-slip creak climbing.
    d = 0.5
    n = int(RATE * d)
    t = t_axis(d)
    slip = 0.55 + 0.45 * (np.sin(2 * np.pi * (22 * t + 30 * t * t)) > 0.3)
    creak = lowpass(osc(slide(70, 150, d, 0.8) + 8 * np.sin(2 * np.pi * 9 * t), "saw"), slide(500, 1600, d)) * slip
    grain = lowpass(highpass(noise(d), 700), 2200) * slip * 0.35
    save("bark_creak", mix(creak, grain) * env(n, 0.3, 0.5), 0.5)

    # The lance driven out: a woody rush ending on a hard thock.
    d = 0.2
    n = int(RATE * d)
    rush = lowpass(highpass(noise(d), 400), slide(1200, 4200, d, 0.5)) * env(n, 0.08, 1.4)
    thock = lowpass(osc(slide(320, 160, 0.06), "tri"), 2000) * env(int(RATE * 0.06), 0.0005, 2.0)
    out = rush * 0.7
    out[-len(thock):] += thock
    save("lance_thrust", out, 0.6)

    # A bark plate knocked off: a dry crack with a hollow wooden knock under it.
    d = 0.11
    n = int(RATE * d)
    crack = highpass(noise(0.025), 2500) * env(int(RATE * 0.025), 0.0005, 2.5)
    knock = lowpass(osc(slide(360, 170, d), "tri"), 1800) * env(n, 0.001, 1.6)
    save("bark_chip", mix(crack, knock * 0.8), 0.6)

    # Rooting: roots biting into the branch, a low crunch with splinters.
    d = 0.4
    n = int(RATE * d)
    splinters = highpass(noise(d) * (np.random.default_rng(11).random(n) > 0.93), 1500)
    bite = lowpass(noise(d), slide(500, 120, d)) * 1.2
    save("root_grip", mix(bite, splinters * 0.5) * env(n, 0.01, 1.3), 0.6)

    # Drowned Dwarf heaving the anchor: a sodden groan with bubbles rising
    # through it and water pouring off the iron.
    d = 0.55
    n = int(RATE * d)
    groan = lowpass(osc(slide(48, 85, d, 0.7), "saw"), slide(180, 600, d)) * env(n, 0.35, 0.5)
    bubbles = np.zeros(n)
    brng = np.random.default_rng(23)
    for i in range(9):
        start = int(n * (0.1 + 0.8 * i / 9 + brng.uniform(0, 0.05)))
        m = int(RATE * 0.04)
        if start + m > n:
            break
        bubbles[start:start + m] += osc(slide(300 + 40 * i, 700 + 60 * i, 0.04), "sine") * env(m, 0.002, 2.0)
    pour = lowpass(highpass(noise(d), 900), 3000) * env(n, 0.4, 0.4) * 0.25
    save("anchor_heave", mix(groan, bubbles * 0.5, pour), 0.6)

    # The anchor coming down: a deep iron thud into mud, then a wet slap.
    d = 0.32
    n = int(RATE * d)
    thud = lowpass(osc(slide(110, 40, d), "square", 0.45), 900) * env(n, 0.001, 1.4)
    slap = lowpass(highpass(noise(d), 300), slide(3000, 400, d)) * env(n, 0.003, 2.2) * 0.8
    save("anchor_slam", mix(thud, slap), 0.8)

    # Leaf Mantis unfolding: a rustle of leaves, then a quick chitter.
    d = 0.3
    n = int(RATE * d)
    rustle = highpass(lowpass(noise(d), slide(2500, 6000, d)), 1200) * env(n, 0.15, 0.8) * 0.6
    t = t_axis(d)
    chitter = osc(np.full(n, 2400.0), "square", 0.2) * (np.sin(2 * np.pi * 38 * t) > 0.6) * (t > 0.16) * 0.25
    save("mantis_unfold", mix(rustle, lowpass(chitter, 5000)), 0.45)

    # The mantis' scythes: two thin cuts a hair apart.
    d = 0.16
    n = int(RATE * d)
    cut = highpass(lowpass(noise(0.07), slide(9000, 2500, 0.07)), 1500) * env(int(RATE * 0.07), 0.002, 1.5)
    out = np.zeros(n)
    out[:len(cut)] += cut
    out[int(RATE * 0.06):int(RATE * 0.06) + len(cut)] += cut * 0.8
    save("scythe", out, 0.55)

    # Seed Bomber (pass 114). The tell: hard seeds rattling in the husk of its
    # belly, faster and higher as it squeezes them toward the drop.
    d = 0.5
    n = int(RATE * d)
    t = t_axis(d)
    rate = 18 + 60 * (t / d) ** 1.5
    gate = (np.sin(2 * np.pi * np.cumsum(rate) / RATE) > 0.75).astype(float)
    clicks = lowpass(highpass(noise(d), slide(900, 2400, d)), 5200) * gate
    husk = lowpass(osc(slide(140, 260, d, 0.8), "tri"), 900) * gate * 0.35
    save("seed_rattle", mix(clicks, husk) * env(n, 0.3, 0.4), 0.5)

    # The seed let go: a pop from the husk and a short falling whistle.
    d = 0.22
    n = int(RATE * d)
    pop = lowpass(osc(slide(520, 220, 0.04), "square", 0.4), 2500) * env(int(RATE * 0.04), 0.0005, 2.0)
    whistle = osc(slide(1700, 900, d, 0.7), "sine") * env(n, 0.03, 1.0) * 0.35
    save("seed_drop", mix(pop, whistle), 0.5)

    # A seed's fuse: a sputtering hiss that climbs as it splits open.
    d = 0.55
    n = int(RATE * d)
    t = t_axis(d)
    sput = 0.4 + 0.6 * (np.sin(2 * np.pi * (14 * t + 40 * t * t)) > 0.0)
    hiss = lowpass(highpass(noise(d), slide(1500, 4000, d)), 7000) * sput
    tick = osc(slide(600, 1100, d), "square", 0.3) * (np.sin(2 * np.pi * (8 * t + 16 * t * t)) > 0.92) * 0.3
    save("seed_fuse", mix(hiss, lowpass(tick, 3000)) * env(n, 0.45, 0.3), 0.45)

    # It bursts: the husk cracks and thorns spray out.
    d = 0.3
    n = int(RATE * d)
    crack = lowpass(noise(d), slide(4000, 300, d)) * env(n, 0.001, 2.0)
    body = lowpass(osc(slide(180, 60, d), "square", 0.5), 700) * env(n, 0.001, 1.8) * 0.8
    spray = highpass(noise(d) * (np.random.default_rng(31).random(n) > 0.9), 3000) * env(n, 0.01, 1.2) * 0.5
    save("seed_burst", mix(crack, body, spray), 0.7)

    # Marsh Hag (pass 119). The hex: a dry cackle, four falling "heh"s through a
    # nasal band, over bog bubbles welling up faster under the mark.
    d = 0.6
    n = int(RATE * d)
    t = t_axis(d)
    cackle = np.zeros(n)
    for k in range(4):
        st = int(RATE * (0.02 + k * 0.11))
        ln = int(RATE * 0.08)
        f0 = 520 - k * 45
        v = osc(slide(f0 * 1.15, f0, ln / RATE), "saw", 0.5) * env(ln, 0.005, 1.6)
        v = lowpass(highpass(v, 700), 2600)
        cackle[st:st + ln] += v[:max(0, min(ln, n - st))]
    rate = 6 + 30 * (t / d)
    pops = (np.sin(2 * np.pi * np.cumsum(rate) / RATE) > 0.9).astype(float)
    bub = lowpass(osc(slide(180, 420, d), "sine") * pops, 1200) * 0.6
    save("hag_hex", mix(cackle * 0.8, bub) * env(n, 0.05, 0.6), 0.5)

    # The mire grasp: a wet squelch as the mud hand bursts up, and a thick slap.
    d = 0.32
    n = int(RATE * d)
    squelch = lowpass(noise(d), slide(1800, 250, d, 0.6)) * env(n, 0.002, 1.6)
    gulp = lowpass(osc(slide(90, 200, 0.08), "sine"), 600) * env(int(RATE * 0.08), 0.001, 1.0)
    out = squelch.copy()
    out[:len(gulp)] += gulp * 0.9
    save("mire_grasp", out, 0.6)

    # Struck mid-hex: the staff clatters into the mud and she croaks.
    d = 0.4
    n = int(RATE * d)
    clack = np.zeros(n)
    for st in (0.0, 0.07, 0.12):
        i = int(RATE * st)
        ln = int(RATE * 0.05)
        clack[i:i + ln] += lowpass(highpass(noise(0.05), 900), 3500)[:ln] * env(ln, 0.001, 3.0)
    croak = lowpass(osc(slide(240, 140, d), "saw", 0.4), 900) * (np.sin(2 * np.pi * 34 * t_axis(d)) > 0).astype(float) * env(n, 0.05, 1.0) * 0.5
    save("hag_fumble", mix(clack, croak), 0.55)

    # The Inner Rings (pass 116). Carried into the inner rings: a shimmer
    # rising through a fifth, like the room drawing a breath.
    d = 0.6
    n = int(RATE * d)
    t = t_axis(d)
    rise = slide(440, 660, d, 0.6)
    shimmer = sum(osc(rise * k, "sine") * w for k, w in ((1, 1.0), (2, 0.35), (3.01, 0.15)))
    shimmer *= 0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)
    breath = lowpass(highpass(noise(d), 1500), slide(2000, 7000, d)) * 0.15
    save("trial_begin", mix(shimmer, breath) * env(n, 0.25, 0.8), 0.45)

    # The bell at a trial's end: a struck bronze bell, inharmonic partials
    # ringing out long, a hum under the strike.
    d = 1.6
    n = int(RATE * d)
    t = t_axis(d)
    f0 = 523.0
    ring = np.zeros(n)
    for ratio, amp, decay in ((0.5, 0.5, 1.2), (1.0, 1.0, 2.0), (1.19, 0.6, 2.6), (1.5, 0.4, 3.0), (2.0, 0.45, 3.5), (2.74, 0.25, 5.0), (4.07, 0.15, 7.0)):
        ring += osc(np.full(n, f0 * ratio), "sine") * amp * np.exp(-t * decay)
    strike = highpass(noise(0.02), 2000) * env(int(RATE * 0.02), 0.0005, 2.0) * 0.6
    ring[: len(strike)] += strike
    save("trial_bell", ring * env(n, 0.001, 0.2), 0.6)

    # A new best: three bright rising notes, the last held.
    out = np.zeros(int(RATE * 0.55))
    for i, f in enumerate((784.0, 988.0, 1175.0)):
        dn = 0.32 if i == 2 else 0.1
        m = int(RATE * dn)
        note = (osc(np.full(m, f), "square", 0.3) * 0.4 + osc(np.full(m, f * 2), "sine") * 0.3) * env(m, 0.003, 1.2)
        at = int(RATE * 0.09 * i)
        out[at:at + m] += lowpass(note, 5000)
    save("trial_record", out, 0.38)

    # The boss rush (pass 157). The bronze bell of the trials, rung for the
    # rush's turns. A boss down, and the ring mends you: the bell struck
    # soft, with a warm swell rising a fourth under it.
    def bell(f0, d, decays=1.0):
        n = int(RATE * d)
        t = t_axis(d)
        ring = np.zeros(n)
        for ratio, amp, decay in ((0.5, 0.5, 1.2), (1.0, 1.0, 2.0), (1.19, 0.6, 2.6), (1.5, 0.4, 3.0), (2.0, 0.45, 3.5), (2.74, 0.25, 5.0)):
            ring += osc(np.full(n, f0 * ratio), "sine") * amp * np.exp(-t * decay * decays)
        strike = highpass(noise(0.02), 2000) * env(int(RATE * 0.02), 0.0005, 2.0) * 0.5
        ring[: len(strike)] += strike
        return ring * env(n, 0.001, 0.2)

    d = 1.2
    n = int(RATE * d)
    t = t_axis(d)
    swell = sum(osc(slide(392, 523, d, 0.5) * k, "sine") * w for k, w in ((1, 0.6), (2, 0.2), (3, 0.08)))
    swell *= np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    save("rush_mend", mix(bell(659.0, d, 1.4) * 0.7, swell * 0.5), 0.45)

    # The rush won: the bell rung three times climbing the chord, the last
    # left to ring out.
    d = 2.4
    out = np.zeros(int(RATE * d))
    for i, f in enumerate((523.0, 659.0, 784.0)):
        tone = bell(f, d - 0.22 * i, 1.0 if i == 2 else 1.6)
        at = int(RATE * 0.22 * i)
        out[at:at + len(tone)] += tone * (1.0 if i == 2 else 0.75)
    save("rush_won", out, 0.5)

    # The rush ends: the bell low and muffled, a damped toll that sinks.
    d = 1.6
    n = int(RATE * d)
    toll = lowpass(bell(196.0, d, 1.3), 1800)
    sink = lowpass(osc(slide(98, 70, d), "saw", 0.5), 400) * env(n, 0.02, 1.6) * 0.35
    save("rush_fall", mix(toll, sink), 0.55)

    # A ring dye won (pass 164): the cloak takes the trial's color. Cloth
    # swept open (a breathy swish rising), and over it the trial bell struck
    # high and light, three quick notes falling into a held chord like dye
    # running through the weave.
    d = 1.5
    n = int(RATE * d)
    t = t_axis(d)
    swish = lowpass(highpass(noise(d), 600), 3200) * np.exp(-((t - 0.18) ** 2) / 0.012) * 0.5
    out = np.zeros(n)
    for i, f in enumerate((1568.0, 1319.0, 1047.0)):
        tone = bell(f, d - 0.11 * i, 2.4 if i < 2 else 1.6)
        at = int(RATE * (0.12 + 0.11 * i))
        out[at:at + len(tone)] += tone[: n - at] * (0.55 if i < 2 else 0.8)
    save("dye_won", mix(out, swish), 0.42)

    # Executioner (pass 163): a blow into a boss's opening. Under the cut, a
    # heavy cleave: a low body thud, a crack, and a short hard ring of the
    # blade biting deep.
    d = 0.32
    n = int(RATE * d)
    thud = lowpass(osc(slide(150, 55, d, 0.4), "sine"), 400) * env(n, 0.001, 2.4)
    crack = highpass(noise(d), 1500) * env(n, 0.0005, 7.0) * 0.6
    ring = (osc(np.full(n, 1180.0), "sine") * 0.4 + osc(np.full(n, 1770.0), "sine") * 0.2) * env(n, 0.001, 4.0)
    save("execute", mix(thud, crack, ring), 0.6)

    # Card doors (pass 122). Locked: the latch rattles in its iron keep and the
    # door knocks twice against the bolt, dull and heavy. Nothing gives.
    d = 0.34
    n = int(RATE * d)
    out = np.zeros(n)
    for st, f in ((0.0, 120.0), (0.13, 105.0)):
        i = int(RATE * st)
        ln = int(RATE * 0.12)
        thud = lowpass(osc(slide(f * 1.6, f, 0.12, 0.5), "sine"), 500) * env(ln, 0.001, 2.2)
        knock = lowpass(noise(0.12), 900) * env(ln, 0.001, 3.5) * 0.5
        out[i:i + ln] += (thud + knock)[:max(0, min(ln, n - i))]
    for st in (0.03, 0.055, 0.16, 0.19):
        i = int(RATE * st)
        ln = int(RATE * 0.025)
        rattle = lowpass(highpass(noise(0.025), 1800), 5000) * env(ln, 0.0005, 3.0) * 0.45
        out[i:i + ln] += rattle[:max(0, min(ln, n - i))]
    save("door_locked", out, 0.6)

    # The key turns: three ratchet clicks of the wards, the bolt's heavy thunk
    # as it draws back, and a small bright chime: the treasure is yours.
    d = 0.75
    n = int(RATE * d)
    t = t_axis(d)
    out = np.zeros(n)
    for st in (0.0, 0.05, 0.1):
        i = int(RATE * st)
        ln = int(RATE * 0.02)
        out[i:i + ln] += lowpass(highpass(noise(0.02), 2500), 7000)[:ln] * env(ln, 0.0005, 3.0) * 0.5
    i = int(RATE * 0.16)
    ln = int(RATE * 0.16)
    bolt = lowpass(osc(slide(160, 80, 0.16, 0.6), "square", 0.4), 700) * env(ln, 0.002, 2.0)
    bolt += lowpass(noise(0.16), 1200) * env(ln, 0.001, 3.0) * 0.4
    out[i:i + ln] += bolt
    i = int(RATE * 0.26)
    m = n - i
    tc = t[:m]
    chime = sum(osc(np.full(m, f), "sine") * a for f, a in ((1319.0, 0.35), (1976.0, 0.22), (2637.0, 0.1)))
    out[i:] += chime * np.exp(-tc * 6.0)
    save("key_turn", out * env(n, 0.001, 0.3), 0.55)

    # The Spire Sentinel (pass 123). Grinding after you: stone dragged on stone,
    # a low rumble under gritty scrape.
    d = 0.45
    n = int(RATE * d)
    t = t_axis(d)
    grit = lowpass(highpass(noise(d), 300), 1400) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * t))
    rumble = lowpass(osc(np.full(n, 55.0) + 4 * np.sin(2 * np.pi * 7 * t), "saw"), 300) * 0.6
    save("sentinel_grind", mix(grit, rumble) * env(n, 0.04, 1.0), 0.5)

    # The halberd raised: stone creaking up over a rising electric hum as the
    # glyph wakes.
    d = 0.55
    n = int(RATE * d)
    t = t_axis(d)
    hum = osc(slide(110, 330, d, 0.8), "saw") * 0.35
    hum = lowpass(hum * (0.7 + 0.3 * np.sin(2 * np.pi * 60 * t)), 2400)
    creak = lowpass(highpass(noise(d), 600), slide(900, 2600, d)) * (np.sin(2 * np.pi * 21 * t) > 0.3).astype(float) * 0.35
    save("sentinel_raise", mix(hum, creak) * env(n, 0.25, 0.5), 0.5)

    # The slam: a stone blade into the floor, a deep thud, a crack and grit.
    d = 0.5
    n = int(RATE * d)
    thud = lowpass(osc(slide(140, 45, 0.25, 0.5), "sine"), 400)
    thud = np.pad(thud, (0, n - len(thud))) * env(n, 0.001, 2.0)
    crack = lowpass(highpass(noise(d), 1200), 6000) * env(n, 0.0005, 6.0) * 0.6
    grit = lowpass(noise(d), 1800) * env(n, 0.01, 2.5) * 0.4
    save("sentinel_slam", mix(thud, crack, grit), 0.65)

    # Ladders (pass 124): a hand or boot on a wooden rung, a hollow knock with a
    # short dry creak after it.
    d = 0.16
    n = int(RATE * d)
    knock = lowpass(osc(slide(320, 220, 0.05), "sine"), 900)
    knock = np.pad(knock, (0, n - len(knock))) * env(n, 0.001, 3.0)
    creak = lowpass(highpass(noise(d), 700), 2200) * (np.sin(2 * np.pi * 45 * t_axis(d)) > 0.5).astype(float) * env(n, 0.02, 2.0) * 0.35
    save("ladder", mix(knock, creak), 0.5)

    # The map (pass 128): a sheet of parchment. Opening it is a rustle that
    # crackles as it unrolls and settles with a soft flap on the table.
    d = 0.42
    n = int(RATE * d)
    t = t_axis(d)
    grain = (rng.uniform(0, 1, n) > 0.93).astype(float) * rng.uniform(-1, 1, n)
    crinkle = lowpass(highpass(grain + noise(d) * 0.25, 1500), slide(3200, 5200, d)) * np.clip(np.sin(np.pi * t / 0.34), 0, 1)
    flap = lowpass(noise(0.08), 700) * env(int(RATE * 0.08), 0.004, 2.5)
    flap = np.pad(flap, (int(RATE * 0.32), 0))[:n] * 0.9
    save("map_open", mix(crinkle * 0.7, flap), 0.65)

    # Closing: quicker, the sheet folded in on itself with a dull pat.
    d = 0.24
    n = int(RATE * d)
    t = t_axis(d)
    grain = (rng.uniform(0, 1, n) > 0.92).astype(float) * rng.uniform(-1, 1, n)
    crinkle = lowpass(highpass(grain + noise(d) * 0.25, 1300), slide(4600, 2400, d)) * np.clip(np.sin(np.pi * t / 0.2), 0, 1)
    pat = lowpass(osc(slide(160, 90, 0.06), "sine"), 500) * env(int(RATE * 0.06), 0.002, 2.0)
    pat = np.pad(pat, (int(RATE * 0.17), 0))[:n]
    save("map_close", mix(crinkle * 0.7, pat * 0.8), 0.55)

    # A pin pressed into the parchment: a tiny tick and a short bright ring.
    d = 0.18
    n = int(RATE * d)
    tick = highpass(noise(0.01), 2500) * env(int(RATE * 0.01), 0.0005, 3.0)
    ring = osc(np.full(n, 2350.0), "sine") * 0.5 + osc(np.full(n, 3525.0), "sine") * 0.2
    save("pin", mix(tick, ring * env(n, 0.001, 4.0) * 0.5), 0.6)

    # Lifting it: the ring first, falling, and the tick of the pin coming free.
    d = 0.16
    n = int(RATE * d)
    ring = osc(slide(2350, 1700, d), "sine") * env(n, 0.001, 4.0) * 0.4
    tick = np.pad(highpass(noise(0.008), 2500) * env(int(RATE * 0.008), 0.0005, 3.0), (int(RATE * 0.04), 0))
    save("pin_lift", mix(ring, tick), 0.5)

    # Death (pass 132): a deep tolling knell under a rushing dark swell, the
    # ring of black light rolling out.
    d = 1.1
    n = int(RATE * d)
    t = t_axis(d)
    toll = sum(osc(np.full(n, f), "sine") * a for f, a in [(55.0, 1.0), (110.5, 0.5), (164.0, 0.3), (231.0, 0.15)])
    toll = toll * env(n, 0.004, 2.2)
    swell = lowpass(noise(d), slide(300, 2200, d, 0.6)) * np.sin(np.pi * np.clip(t / 0.6, 0, 1)) * 0.6
    swell = swell * np.clip(1.2 - t / d, 0, 1)
    save("death_wave", mix(toll, swell), 0.7)

    # Wind current (pass 137): a gust catching the cloak, a rush of air that
    # swells and blows past.
    d = 0.5
    n = int(RATE * d)
    t = t_axis(d)
    gust = highpass(lowpass(noise(d), slide(700, 2400, d, 0.5)), 250) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    flap = lowpass(noise(d), 900) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * t))) * env(n, 0.02, 1.2) * 0.35
    save("wind_catch", mix(gust, flap), 0.4)

    # Wrong gravity (pass 137): stepping into the pocket, a hollow glassy shimmer
    # that rises as the weight lifts; stepping out, a low hum that drops and a
    # soft thud as the true pull takes hold.
    d = 0.6
    n = int(RATE * d)
    t = t_axis(d)
    rise = sum(osc(slide(f, f * 1.5, d, 0.5), "sine") * a for f, a in [(330.0, 1.0), (495.0, 0.5), (742.0, 0.25)])
    rise = rise * (1 + 0.3 * np.sin(2 * np.pi * 7 * t)) * np.sin(np.pi * np.clip(t / d, 0, 1))
    air = highpass(lowpass(noise(d), slide(1200, 4000, d)), 600) * env(n, 0.1, 1.5) * 0.25
    save("drift_in", mix(rise, air), 0.35)
    d = 0.45
    n = int(RATE * d)
    t = t_axis(d)
    fall = sum(osc(slide(f, f * 0.55, d, 0.7), "sine") * a for f, a in [(220.0, 1.0), (330.0, 0.4)])
    fall = fall * env(n, 0.01, 1.6)
    thud = lowpass(noise(0.12), 220) * env(int(RATE * 0.12), 0.002, 2.5) * 1.4
    save("drift_out", mix(fall, thud), 0.4)

    # Cloak dye (pass 137): a cloth swish and a soft shake of fabric, wearing a dye.
    d = 0.32
    n = int(RATE * d)
    t = t_axis(d)
    swish = highpass(lowpass(noise(d), slide(2500, 5000, d, 0.4)), 900) * env(n, 0.03, 1.8)
    shake = lowpass(noise(d), 1400) * np.abs(np.sin(2 * np.pi * 9 * t)) * env(n, 0.01, 1.5) * 0.5
    save("cloth", mix(swish, shake), 0.4)

    # Thrust (pass 149): the blade's glint as a held charge comes ready, a bright
    # steel shing, and the lunge itself, a tearing rush ending on a hard bite.
    d = 0.26
    n = int(RATE * d)
    shing = mix(osc(slide(2400, 2600, d), "sine") * env(n, 0.002, 2.6),
                osc(slide(3600, 3900, d), "sine") * env(n, 0.002, 3.4) * 0.45)
    save("thrust_ready", mix(shing, highpass(noise(0.03), 4000) * env(int(RATE * 0.03)) * 0.6), 0.45)
    d = 0.22
    n = int(RATE * d)
    rush = highpass(lowpass(noise(d), slide(1800, 7000, d, 0.6)), 600) * env(n, 0.05, 1.3)
    bite = lowpass(osc(slide(260, 90, 0.08), "square", 0.4), 1800) * env(int(RATE * 0.08), 0.0005, 1.8)
    out = rush * 0.8
    out[-len(bite):] += bite * 0.8
    save("thrust", out, 0.75)

    # Voices of their own for the mini-bosses (pass 173).
    # The Clockwork Alpha winding up: a big key turned in four heavy detents,
    # each a deep clank with a spring groan climbing behind it.
    d = 0.6
    n = int(RATE * d)
    clanks = np.zeros(n)
    for i, at in enumerate([0.0, 0.14, 0.27, 0.39]):
        start = int(RATE * at)
        m = int(RATE * 0.07)
        part = mix(lowpass(osc(slide(140 + 30 * i, 90 + 20 * i, 0.07), "square", 0.3), 1400),
                   highpass(noise(0.07), 1800) * 0.5) * env(m, 0.0005, 2.4)
        clanks[start:start + m] += part[: n - start]
    groan = lowpass(osc(slide(120, 380, d, 0.7), "saw"), 900) * env(n, 0.2, 0.8) * 0.3
    save("key_wind", mix(clanks, groan), 0.6)

    # Its spring jamming against a wall: a hard clang, then a mainspring
    # buzzing loose with gear teeth skittering.
    d = 0.7
    n = int(RATE * d)
    clang = mix(osc(slide(520, 500, 0.4), "sine"), osc(slide(1290, 1250, 0.4), "sine") * 0.5) * env(int(RATE * 0.4), 0.001, 2.0)
    t = t_axis(d)
    buzz = lowpass(osc(slide(180, 60, d, 0.5) * (1 + 0.15 * np.sin(2 * np.pi * 31 * t)), "square", 0.3), 1200) * env(n, 0.05, 1.2) * 0.5
    teeth = highpass(noise(d) * (np.random.default_rng(17).random(n) > 0.96), 2600) * env(n, 0.01, 1.0) * 0.6
    save("spring_jam", mix(clang, buzz, teeth), 0.6)

    # The Bark Knight Captain's vault: the lance planted and flexed (a deep
    # woody groan), then the spring of the bough throwing him up (a rush).
    d = 0.55
    n = int(RATE * d)
    t = t_axis(d)
    flex = lowpass(osc(slide(55, 110, d, 0.9) + 6 * np.sin(2 * np.pi * 7 * t), "saw"), slide(400, 1300, d)) * env(n, 0.25, 0.6)
    rush = lowpass(highpass(noise(d), 300), slide(600, 3000, d, 1.8)) * np.clip((t - 0.3) / 0.25, 0, 1) * 0.6
    save("bough_vault", mix(flex, rush), 0.4)

    # His landing, lance-first: a deep wooden boom and roots tearing the floor.
    d = 0.5
    n = int(RATE * d)
    boom = lowpass(osc(slide(110, 45, 0.3, 0.6), "tri"), 700) * env(int(RATE * 0.3), 0.001, 1.6)
    tear = lowpass(noise(d), slide(900, 150, d)) * env(n, 0.005, 1.5) * 0.7
    splinters = highpass(noise(d) * (np.random.default_rng(23).random(n) > 0.94), 1800) * env(n, 0.005, 2.0) * 0.4
    save("lance_plant", mix(boom, tear, splinters), 0.7)


    # The Marsh Hag Matriarch (pass 179). Her cackle: the hags' "heh"s, lower
    # and slower, six of them climbing then breaking, over a wet bog drone.
    d = 0.9
    n = int(RATE * d)
    laugh = np.zeros(n)
    for k in range(6):
        st = int(RATE * (0.02 + k * 0.12))
        ln = int(RATE * 0.1)
        f0 = 300 + (k * 30 if k < 4 else (6 - k) * 40)
        v = osc(slide(f0 * 1.2, f0, ln / RATE), "saw", 0.5) * env(ln, 0.005, 1.4)
        v = lowpass(highpass(v, 400), 2000)
        laugh[st:st + ln] += v[:max(0, min(ln, n - st))]
    drone = lowpass(osc(slide(70, 60, d), "saw"), 300) * env(n, 0.1, 0.8) * 0.4
    save("matriarch_cackle", mix(laugh * 0.8, drone), 0.55)

    # Sinking into the bog: a long glug sliding down and a closing slurp.
    d = 0.5
    n = int(RATE * d)
    t = t_axis(d)
    rate = 18 - 12 * (t / d)
    pops = (np.sin(2 * np.pi * np.cumsum(rate) / RATE) > 0.8).astype(float)
    glug = lowpass(osc(slide(320, 90, d), "sine") * pops, 900) * env(n, 0.02, 1.0)
    slurp = lowpass(noise(d), slide(1400, 200, d)) * np.clip((t - 0.3) / 0.2, 0, 1) * env(n, 0.3, 1.5) * 0.5
    save("bog_sink", mix(glug, slurp), 0.55)

    # Rising out of it: the bog bursting open and water streaming off.
    d = 0.5
    n = int(RATE * d)
    burst = lowpass(osc(slide(80, 220, 0.12), "sine"), 700) * env(int(RATE * 0.12), 0.001, 1.0)
    stream = lowpass(highpass(noise(d), 500), slide(3000, 900, d)) * env(n, 0.01, 1.4) * 0.6
    out = stream.copy()
    out[:len(burst)] += burst
    save("bog_rise", out, 0.55)

    # A step in marsh mud (pass 181): a wet slap as the boot goes in, then a
    # small suction pop as it pulls free.
    d = 0.16
    n = int(RATE * d)
    sn = int(RATE * 0.05)
    slap = lowpass(highpass(noise(0.05), 180), 1600) * env(sn, 0.001, 2.2)
    pn = int(RATE * 0.05)
    pop = lowpass(osc(slide(260, 720, 0.05, 0.6), "sine"), 1400) * env(pn, 0.004, 1.6) * 0.55
    out = np.zeros(n)
    out[:sn] += slap
    out[int(RATE * 0.07):int(RATE * 0.07) + pn] += pop
    save("step_mud", out, 0.45)

    # The Rune Dagger (pass 184). Thrown: a tight whip of air with the blade's
    # thin ring in it, rising.
    d = 0.18
    n = int(RATE * d)
    whip = lowpass(highpass(noise(d), 900), slide(5200, 1800, d)) * env(n, 0.004, 2.0)
    ring = osc(slide(1900, 2300, d), "sine") * env(n, 0.002, 2.6) * 0.35
    save("dagger_throw", mix(whip, ring), 0.5)

    # Reforming at your side: motes of light falling together, a rising
    # shimmer, then a soft bright chime as the blade is whole again.
    d = 0.42
    n = int(RATE * d)
    shimmer = osc(slide(900, 2400, 0.28, 0.6), "sine") * env(int(RATE * 0.28), 0.2, 0.6) * 0.3
    sparkle = highpass(noise(0.28), 3500) * env(int(RATE * 0.28), 0.25, 0.5) * 0.25
    cn = int(RATE * 0.16)
    chime = mix(osc(np.full(cn, 1760.0), "sine"), osc(np.full(cn, 2640.0), "sine") * 0.5) * env(cn, 0.002, 2.2)
    out = np.zeros(n)
    out[:len(shimmer)] += shimmer + sparkle
    out[int(RATE * 0.25):int(RATE * 0.25) + cn] += chime
    save("dagger_return", out, 0.45)

    # A dagger's strike (pass 190): it had none, so a throw that landed was
    # silent. A short thin bite: a high tick of the point going in and a small
    # dry knock under it, lighter than a blade's hit.
    d = 0.08
    n = int(RATE * d)
    tick = highpass(noise(0.02), 2500) * env(int(RATE * 0.02), 0.001, 2.0)
    knock = lowpass(osc(slide(420, 260, d), "tri"), 2200) * env(n, 0.001, 2.4) * 0.7
    out = np.zeros(n)
    out[:len(tick)] += tick
    out += knock
    save("dagger_hit", out, 0.5)

    # A dagger that strikes stone (pass 326): it borrowed the shield's `guard`
    # clank, so a throw at a wall sounded like a block. A glancing steel ping
    # (two inharmonic partials, short) over a gritty tick of the point.
    d = 0.14
    n = int(RATE * d)
    grit = highpass(noise(0.015), 3000) * env(int(RATE * 0.015), 0.0005, 2.0) * 0.6
    ping = mix(osc(np.full(n, 2860.0), "sine"), osc(np.full(n, 4170.0), "sine") * 0.45) * env(n, 0.001, 3.2) * 0.55
    out = np.zeros(n)
    out[:len(grit)] += grit
    out += ping
    save("dagger_ping", out, 0.4)

    # The Dwarvish Broad Sword (pass 190), two-handed and 30% slower: its cuts
    # are a longer, lower rush of air with a weight under it, so the blade in
    # hand is heard. The heavy cut adds a deeper body.
    d = 0.17
    n = int(RATE * d)
    rush = highpass(lowpass(noise(d), slide(3800, 700, d, 0.7)), 250) * env(n, 0.02, 1.3)
    weight = lowpass(osc(slide(110, 60, d), "square", 0.45), 900) * env(n, 0.03, 1.4) * 0.35
    save("broad_slash", mix(rush, weight), 0.65)
    d = 0.22
    n = int(RATE * d)
    rush = highpass(lowpass(noise(d), slide(3200, 500, d, 0.7)), 200) * env(n, 0.025, 1.2)
    body = lowpass(osc(slide(95, 42, d), "square", 0.45), 1200) * env(n, 0.002, 1.0) * 0.8
    save("broad_heavy", mix(rush, body), 0.75)

    # The Equipment page (pass 190): changing gear had the cloth swish of a dye.
    # A blade taken in hand slides from its sheath and seats with a click; armor,
    # a shield or a helmet goes on with a buckle's clink over leather.
    d = 0.3
    n = int(RATE * d)
    scrape = highpass(lowpass(noise(0.22), slide(4500, 7000, 0.22)), 1800) * env(int(RATE * 0.22), 0.05, 1.0) * 0.6
    cn = int(RATE * 0.06)
    click = mix(highpass(noise(0.06), 2000) * env(cn, 0.001, 3.0), osc(np.full(cn, 2900.0), "sine") * env(cn, 0.001, 2.5) * 0.4)
    out = np.zeros(n)
    out[:len(scrape)] += scrape
    out[int(RATE * 0.22):int(RATE * 0.22) + cn] += click
    save("sheathe", out, 0.45)
    d = 0.3
    n = int(RATE * d)
    leather = lowpass(highpass(noise(0.16), 300), 1800) * env(int(RATE * 0.16), 0.01, 1.6) * 0.6
    kn = int(RATE * 0.12)
    clink = mix(osc(np.full(kn, 1480.0), "sine"), osc(np.full(kn, 2210.0), "sine") * 0.6) * env(kn, 0.001, 2.4) * 0.5
    out = np.zeros(n)
    out[:len(leather)] += leather
    out[int(RATE * 0.12):int(RATE * 0.12) + kn] += clink
    out[int(RATE * 0.18):int(RATE * 0.18) + kn] += clink * 0.6
    save("gear_on", out, 0.45)

    # A guardian falls (pass 222). The win had played `item`, the same chime as
    # a loaf of bread off the floor. Now it has a fanfare of its own, the old
    # 8-bit victory call: three quick brassy G's, then a held C major chord
    # over a timpani roll and a low root, ringing out as the boss theme stops.
    d = 2.4
    n = int(RATE * d)
    out = np.zeros(n)
    def brass(f, dur, decay):
        m = int(RATE * dur)
        tone = osc(np.full(m, f), "saw", 0.5) * 0.5 + osc(np.full(m, f), "square", 0.3) * 0.35
        vib = 1.0 + 0.04 * np.sin(2 * np.pi * 5.5 * t_axis(dur)) * np.clip(t_axis(dur) / 0.3, 0, 1)
        return lowpass(tone * vib, 2600) * env(m, 0.01, decay)
    for i in range(3):
        note = brass(392.0, 0.11, 0.8)
        at = int(RATE * 0.12 * i)
        out[at:at + len(note)] += note * 0.8
    hold = 0.36
    for f, amp in ((523.0, 1.0), (659.0, 0.6), (784.0, 0.6), (1047.0, 0.35)):
        note = brass(f, d - hold, 1.4)
        out[int(RATE * hold):int(RATE * hold) + len(note)] += note * amp
    root = lowpass(osc(np.full(n - int(RATE * hold), 131.0), "tri", 0.5), 500) * env(n - int(RATE * hold), 0.01, 1.6)
    out[int(RATE * hold):] += root * 0.7
    for k, at in enumerate((0.0, 0.12, 0.24, 0.36)):
        tn = int(RATE * 0.5)
        timp = lowpass(osc(slide(98 if k == 3 else 82, 60, 0.5, 0.7), "sine"), 300) * env(tn, 0.002, 2.0)
        timp += lowpass(noise(0.5), 800) * env(tn, 0.001, 6.0) * 0.3
        s0 = int(RATE * at)
        out[s0:s0 + tn] += timp * (1.0 if k == 3 else 0.5)
    save("boss_won", out, 0.6)

    # Wading Vorrhallow's standing water (pass 262): the shin pushing water
    # aside in a slosh, and a couple of drips falling back off the boot.
    d = 0.24
    n = int(RATE * d)
    t = t_axis(d)
    slosh = lowpass(highpass(noise(d), 220), slide(1800, 500, d)) * env(n, 0.03, 1.8)
    out = slosh * 0.8
    for at, f in ((0.11, 1500.0), (0.17, 1900.0)):
        dn = int(RATE * 0.04)
        drip = osc(slide(f, f * 1.6, 0.04, 0.5), "sine") * env(dn, 0.001, 3.0) * 0.3
        out[int(RATE * at):int(RATE * at) + dn] += drip
    save("step_wade", out, 0.5)

    # A Mothling's tell (pass 262): a thin shriek rising through the beat of
    # its wings, before the dive.
    d = 0.4
    n = int(RATE * d)
    t = t_axis(d)
    wings = 0.6 + 0.4 * np.sin(2 * np.pi * 26 * t)
    cry = osc(slide(820, 1700, d, 0.7) * (1 + 0.03 * np.sin(2 * np.pi * 9 * t)), "saw")
    cry = lowpass(highpass(cry, 500), 3200) * wings * env(n, 0.06, 1.2)
    flap = lowpass(highpass(noise(d), 900), 2600) * wings * env(n, 0.02, 1.0) * 0.35
    save("mothling_screech", mix(cry, flap), 0.55)

    # Its dive: a falling whistle and the air torn past folded wings.
    d = 0.42
    n = int(RATE * d)
    whistle = osc(slide(1500, 480, d, 0.8), "sine") * env(n, 0.01, 1.3)
    rush = lowpass(highpass(noise(d), 600), slide(4200, 1100, d)) * env(n, 0.12, 1.1) * 0.7
    save("mothling_dive", mix(whistle * 0.6, rush), 0.45)

    # The Bloom's petals flaring to loose its brood (pass 262): a dry rustle
    # swelling under a low, rising, many-winged hum.
    d = 0.7
    n = int(RATE * d)
    t = t_axis(d)
    hum = sum(osc(slide(f, f * 1.5, d, 0.8), "saw") for f in (110.0, 113.0, 166.0)) / 3
    hum = lowpass(hum * (0.7 + 0.3 * np.sin(2 * np.pi * 22 * t)), 1200) * np.clip(t / 0.5, 0, 1) * env(n, 0.001, 0.6)
    rustle = lowpass(highpass(noise(d), 1200), 4000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 7 * t))) * np.clip(t / 0.4, 0, 1) * env(n, 0.001, 0.8) * 0.5
    save("bloom_brood", mix(hum, rustle), 0.55)

    # The brood loosed: the petals snapping open with a soft pop, and a
    # flurry of wings scattering out of them.
    d = 0.55
    n = int(RATE * d)
    t = t_axis(d)
    pn = int(RATE * 0.08)
    pop = lowpass(osc(slide(180, 70, 0.08), "sine"), 500) * env(pn, 0.001, 1.5)
    pop += lowpass(noise(0.08), 2400) * env(pn, 0.001, 4.0) * 0.4
    flurry = lowpass(highpass(noise(d), 800), 3600) * (0.55 + 0.45 * np.sin(2 * np.pi * 31 * t)) * env(n, 0.02, 1.4) * 0.7
    out = flurry.copy()
    out[:pn] += pop * 0.5
    save("brood_loose", out, 0.55)

    # A Silt Adder's tell (pass 273): a long rasping hiss swelling as the hood
    # flares, with the dry rattle of scales drawn back.
    d = 0.5
    n = int(RATE * d)
    t = t_axis(d)
    hiss = highpass(lowpass(noise(d), slide(5200, 7600, d)), 2400) * np.clip(t / 0.18, 0, 1) * env(n, 0.001, 0.7)
    rasp = 0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 38 * t))
    scales = lowpass(highpass(noise(d), 900), 2600) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 11 * t))) * env(n, 0.01, 1.6) * 0.35
    save("silt_adder_hiss", mix(hiss * rasp, scales), 0.6)

    # Its strike: the body lashing through the air and the jaws snapping shut.
    d = 0.3
    n = int(RATE * d)
    lash = lowpass(highpass(noise(d), 500), slide(1200, 5200, d, 0.6)) * env(n, 0.03, 1.4)
    sn = int(RATE * 0.05)
    snap = highpass(lowpass(noise(0.05), 6000), 1500) * env(sn, 0.0005, 5.0)
    snap += osc(slide(900, 300, 0.05), "square", 0.3) * env(sn, 0.0005, 5.0) * 0.4
    out = lash * 0.8
    at = int(RATE * 0.2)
    out[at:at + sn] += snap
    save("silt_adder_strike", out, 0.8)

    # An empty flask (pass 286): the cork pulls on nothing. A dry pop, then the
    # hollow glass rings twice, small and high, with no swallow after it.
    d = 0.32
    n = int(RATE * d)
    out = np.zeros(n)
    pn = int(RATE * 0.03)
    out[:pn] += lowpass(highpass(noise(0.03), 600), 3000) * env(pn, 0.0005, 4.0) * 0.6
    for st, f, a in ((0.04, 1760.0, 0.5), (0.12, 2350.0, 0.3)):
        i = int(RATE * st)
        ln = n - i
        ring = osc(slide(f, f * 0.98, ln / RATE), "sine") * env(ln, 0.001, 3.0)
        body = osc(slide(f * 0.25, f * 0.24, ln / RATE), "sine") * env(ln, 0.002, 4.0) * 0.35
        out[i:] += (ring + body)[:ln] * a
    save("flask_empty", out, 0.45)

    # A mana orb taken (pass 294): magic poured back in. It had borrowed the
    # menu cursor's blip. A soft breath of air under three glassy notes rising
    # quickly up a major triad, each with a faint shimmer a fifth above.
    d = 0.42
    n = int(RATE * d)
    out = np.zeros(n)
    out += lowpass(highpass(noise(d), 1800), 6000) * env(n, 0.03, 2.5) * 0.12
    for st, f, a in ((0.0, 880.0, 0.45), (0.05, 1108.7, 0.5), (0.1, 1318.5, 0.6)):
        i = int(RATE * st)
        ln = n - i
        note = osc(np.full(ln, f), "sine") * env(ln, 0.004, 2.2)
        shimmer = osc(np.full(ln, f * 1.5), "sine") * env(ln, 0.01, 3.0) * 0.25
        out[i:] += (note + shimmer) * a
    save("mana_orb", out, 0.4)

    # A poison tick (pass 310): the sickness taking its bite. It was silent,
    # though since pass 306 a tick takes up to 4 health. A small wet glug, a
    # sine bubble sagging from 300 to 170 Hz with a second, smaller one behind
    # it and a breath of murky noise: sick, not struck, and well under `hurt`.
    d = 0.22
    n = int(RATE * d)
    out = np.zeros(n)
    out += lowpass(noise(d), 900) * env(n, 0.01, 2.5) * 0.18
    for st, f0, f1, a in ((0.0, 300.0, 170.0, 0.7), (0.07, 240.0, 150.0, 0.4)):
        i = int(RATE * st)
        ln = n - i
        out[i:] += osc(slide(f0, f1, ln / RATE, 0.6), "sine") * env(ln, 0.004, 2.0) * a
    save("poison_tick", out, 0.3)

    # A Bloodletting heal (pass 318): a blow in a foe's opening giving health
    # back. It was silent, so the skill was felt only as a number on the masks.
    # A warm, quiet double pulse, like a heartbeat taking: two soft sine swells
    # rising 180 to 260 Hz with a faint octave above, kept well under `hit`.
    d = 0.24
    n = int(RATE * d)
    out = np.zeros(n)
    for st, a in ((0.0, 0.7), (0.09, 0.5)):
        i = int(RATE * st)
        ln = n - i
        out[i:] += osc(slide(180.0, 260.0, ln / RATE, 0.5), "sine") * env(ln, 0.012, 3.0) * a
        out[i:] += osc(slide(360.0, 520.0, ln / RATE, 0.5), "sine") * env(ln, 0.012, 4.0) * a * 0.2
    save("bloodlet", out, 0.3)

    # The title's flasks (Sean, 2026-10-31; pass 350). They had borrowed the
    # rank's fanfare, the rest's chime and the water's splash. Taking a flask
    # down: a round cork pop with a little suck of air, then the glow inside
    # swelling up a fifth, soft and warm.
    d = 0.55
    n = int(RATE * d)
    out = np.zeros(n)
    pn = int(RATE * 0.05)
    out[:pn] += lowpass(osc(slide(300, 900, 0.05, 0.5), "sine"), 1800) * env(pn, 0.001, 2.2) * 0.7
    out[:pn] += lowpass(highpass(noise(0.05), 500), 2500) * env(pn, 0.0005, 5.0) * 0.4
    for st, f, a in ((0.08, 523.3, 0.35), (0.16, 784.0, 0.4)):
        i = int(RATE * st)
        ln = n - i
        out[i:] += osc(np.full(ln, f), "sine") * env(ln, 0.03, 1.8) * a
        out[i:] += osc(np.full(ln, f * 2.0), "sine") * env(ln, 0.03, 2.6) * a * 0.15
    save("flask_uncork", out, 0.55)

    # Pouring a journey out: liquid glugging out of the neck, slowing, and the
    # empty glass ringing once, small and high.
    d = 0.75
    n = int(RATE * d)
    t = t_axis(d)
    rate = 14 - 8 * (t / d)
    pops = (np.sin(2 * np.pi * np.cumsum(rate) / RATE) > 0.7).astype(float)
    glug = lowpass(osc(slide(420, 160, d), "sine") * pops, 1100) * env(n, 0.02, 1.2) * 0.8
    stream = lowpass(highpass(noise(d), 900), 3500) * np.clip(1.0 - t / 0.55, 0, 1) * 0.18
    out = glug + stream
    i = int(RATE * 0.58)
    ln = n - i
    out[i:] += osc(slide(2100, 2080, ln / RATE), "sine") * env(ln, 0.001, 3.5) * 0.3
    save("flask_pour", out, 0.6)

    # Reading a lore tablet (pass 358). It had borrowed the door's creak, so
    # every one of the signs sounded like a door. Now a hand brushes the grit
    # off the carving, and the runes answer with a low, soft glow: two quiet
    # stone-struck notes a fourth apart with a hollow hum under them.
    d = 0.6
    n = int(RATE * d)
    t = t_axis(d)
    bn = int(RATE * 0.16)
    out = np.zeros(n)
    out[:bn] += lowpass(highpass(noise(0.16), 1200), 4200) * env(bn, 0.03, 1.4) * 0.35
    for st, f, a in ((0.1, 392.0, 0.45), (0.2, 523.3, 0.35)):
        i = int(RATE * st)
        ln = n - i
        tone = osc(np.full(ln, f), "sine") + 0.3 * osc(np.full(ln, f * 2.76), "sine")
        out[i:] += tone * env(ln, 0.004, 2.6) * a
    out += lowpass(osc(np.full(n, 98.0), "tri"), 400) * np.sin(np.pi * t / d) * 0.2
    save("tablet_read", out, 0.5)

    # A ward that will not let you through (pass 358): the bound fog and the
    # elven veil had borrowed the spell-fail fizzle when they turned you away,
    # though a refusal is not a spell gone wrong (pass 122 gave the locks their
    # own sound for the same reason). Now the ward pushes back: a soft low
    # thrum that swells and is pressed down a step, with a breath of air.
    d = 0.5
    n = int(RATE * d)
    t = t_axis(d)
    swell = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    body = osc(slide(220.0, 147.0, d, 0.6), "sine") + 0.4 * osc(slide(330.0, 220.0, d, 0.6), "tri")
    wob = 1.0 + 0.35 * np.sin(2 * np.pi * 11.0 * t)
    air = lowpass(highpass(noise(d), 300), 1600) * 0.25
    out = (lowpass(body, 900) * wob + air) * swell
    save("ward_refuse", out, 0.45)

    # A menu that says no (pass 366): a disabled row (a ware you can't afford,
    # an Barkbalm you don't have), a pad button the Controls page keeps, and a
    # map with no pin left had all borrowed the spell-fail fizzle, so a shop
    # sounded like a failed cast. Now the menu answers in its own voice: the
    # cursor's square blip, lower and dull, twice, falling a fourth.
    d = 0.17
    n = int(RATE * d)
    out = np.zeros(n)
    for st, f in ((0.0, 330.0), (0.085, 247.0)):
        i = int(RATE * st)
        ln = int(RATE * 0.07)
        out[i:i + ln] += lowpass(osc(np.full(ln, f), "square", 0.35), 1400) * env(ln, 0.002, 1.6)
    save("menu_refuse", out, 0.32)

    # The broken aqueduct's fall (pass 374): the Drowned Aqueduct's waterfall
    # was the one moving water with no voice. A seamless two-second loop the
    # spill plays while you are near: a white hiss of falling water over a low
    # churning roar where it lands, the roar swelling a little as the water
    # gulps. The last half second is laid over the first, so it loops clean.
    d = 2.0
    tail = 0.5
    n = int(RATE * d)
    k = int(RATE * tail)
    t = t_axis(d + tail)
    hiss = lowpass(highpass(noise(d + tail), 900), 4200) * 0.55
    roar = lowpass(highpass(noise(d + tail), 60), 380) * 1.6
    gulp = 1.0 + 0.25 * np.sin(2 * np.pi * 1.5 * t) + 0.12 * np.sin(2 * np.pi * 3.5 * t + 1.0)
    raw = hiss + roar * gulp
    out = raw[:n].copy()
    fade = np.linspace(0, 1, k)
    out[:k] = out[:k] * fade + raw[n:n + k] * (1 - fade)
    save("falls_pour", out, 0.3)

    # The crouch (bible 6.15): a short, soft rustle of cloak and leather as the
    # hero drops low, quieter than a footstep. Last, so the fixed seed leaves
    # every sound above it as it was.
    d = 0.09
    save("crouch", lowpass(noise(d), slide(1800, 500, d)) * env(int(RATE * d), 0.004, 2.2), 0.35)


if __name__ == "__main__":
    main()
