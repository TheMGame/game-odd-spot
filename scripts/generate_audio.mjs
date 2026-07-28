import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const sampleRate = 44100;
const outputDir = resolve("client/assets/audio");
mkdirSync(outputDir, { recursive: true });

function writeWav(name, duration, render, channels = 2) {
  const frames = Math.floor(duration * sampleRate);
  const data = Buffer.alloc(frames * channels * 2);
  for (let i = 0; i < frames; i++) {
    const t = i / sampleRate;
    const values = render(t);
    for (let channel = 0; channel < channels; channel++) {
      const value = Array.isArray(values) ? values[channel] : values;
      data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, value)) * 32767), (i * channels + channel) * 2);
    }
  }
  const header = Buffer.alloc(44);
  header.write("RIFF", 0); header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVEfmt ", 8); header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24); header.writeUInt32LE(sampleRate * channels * 2, 28);
  header.writeUInt16LE(channels * 2, 32); header.writeUInt16LE(16, 34);
  header.write("data", 36); header.writeUInt32LE(data.length, 40);
  writeFileSync(resolve(outputDir, name), Buffer.concat([header, data]));
}

const smooth = (x) => x * x * (3 - 2 * x);
const bell = (t, frequency, decay = 8) =>
  Math.sin(2 * Math.PI * frequency * t) * Math.exp(-decay * t)
  + 0.32 * Math.sin(2 * Math.PI * frequency * 2.01 * t) * Math.exp(-decay * 1.8 * t);

writeWav("ui_click.wav", 0.11, (t) => {
  const env = Math.exp(-34 * t) * Math.min(1, t * 220);
  return 0.22 * env * (Math.sin(2 * Math.PI * 720 * t) + 0.35 * Math.sin(2 * Math.PI * 1080 * t));
});

writeWav("correct.wav", 0.24, (t) => {
  const attack = Math.min(1, t * 500);
  const first = (Math.sin(2 * Math.PI * 987.77 * t)
    + 0.38 * Math.sin(2 * Math.PI * 1975.54 * t)) * Math.exp(-18 * t) * attack;
  const secondTime = t - 0.055;
  const second = secondTime >= 0
    ? (Math.sin(2 * Math.PI * 1318.51 * secondTime)
      + 0.28 * Math.sin(2 * Math.PI * 2637.02 * secondTime))
      * Math.exp(-20 * secondTime) * Math.min(1, secondTime * 500)
    : 0;
  return 0.24 * first + 0.2 * second;
});

writeWav("complete.wav", 1.65, (t) => {
  const notes = [[0, 523.25], [0.16, 659.25], [0.32, 783.99], [0.5, 1046.5], [0.72, 1318.51]];
  return 0.14 * notes.reduce((sum, [start, frequency]) =>
    sum + (t >= start ? bell(t - start, frequency, 3.7) : 0), 0) * Math.min(1, t * 40);
});

const beat = 60 / 92;
const melody = [523.25, 659.25, 783.99, 880, 783.99, 659.25, 587.33, 659.25,
  783.99, 1046.5, 880, 783.99, 659.25, 783.99, 587.33, 523.25];
const bgmDuration = melody.length * beat;
writeWav("quiet_search_loop.wav", bgmDuration, (t) => {
  const local = t % beat;
  const frequency = melody[Math.floor(t / beat) % melody.length];
  const env = Math.exp(-5.2 * local) * Math.min(1, local * 100);
  const pluck = (Math.sin(2 * Math.PI * frequency * local)
    + 0.34 * Math.sin(2 * Math.PI * frequency * 2 * local)
    + 0.12 * Math.sin(2 * Math.PI * frequency * 3 * local)) * env;
  const sparkleLocal = (t + beat * 0.5) % (beat * 2);
  const sparkle = Math.sin(2 * Math.PI * 1318.51 * sparkleLocal)
    * Math.exp(-7 * sparkleLocal) * Math.min(1, sparkleLocal * 100);
  const fade = smooth(Math.min(1, Math.min(t, bgmDuration - t) / 0.35));
  const warmMajor = (Math.sin(2 * Math.PI * 261.63 * t)
    + 0.7 * Math.sin(2 * Math.PI * 329.63 * t)
    + 0.45 * Math.sin(2 * Math.PI * 392 * t)) * fade;
  const pan = Math.sin(2 * Math.PI * t / bgmDuration) * 0.1;
  return [
    0.052 * pluck * (1 - pan) + 0.012 * sparkle + 0.006 * warmMajor,
    0.052 * pluck * (1 + pan) + 0.016 * sparkle + 0.006 * warmMajor,
  ];
});

console.log(`Generated audio in ${outputDir}`);
