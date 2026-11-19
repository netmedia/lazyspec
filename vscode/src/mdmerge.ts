// The formatted editor writes Markdown in its own way (a blank line after a heading, tables padded, characters
// escaped). So that an edit changes only what was edited: the file as it was (original), the editor's
// Markdown of it before the edit (before) and after it (after) - only the stretches of "before" the edit
// changed are replaced in the original, the rest keeps its own text. No VS Code here.

/** A line as the editor and a person may both write it: for aligning them, not for writing. */
function norm(l: string): string {
  return l.trim()
    .replace(/^[*+]\s+/, '- ')
    .replace(/\\([\\`*_{}[\]()#+\-.!|<>~])/g, '$1')
    .replace(/\s*\|\s*/g, '|')
    .replace(/\|:?-{1,}:?(?=\|)/g, '|-')
    .replace(/\s+/g, ' ');
}
/** The longest common subsequence of two lists: index in a -> index in b, for the matched ones. */
function lcs(a: string[], b: string[]): Map<number, number> {
  const n = a.length, m = b.length;
  const map = new Map<number, number>();
  if (!n || !m) { return map; }
  if (n * m > 40_000_000) { return map; }
  const dp = new Uint32Array((n + 1) * (m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      dp[i * (m + 1) + j] = a[i] === b[j] ? dp[(i + 1) * (m + 1) + j + 1] + 1 : Math.max(dp[(i + 1) * (m + 1) + j], dp[i * (m + 1) + j + 1]);
    }
  }
  let i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) { map.set(i, j); i++; j++; }
    else if (dp[(i + 1) * (m + 1) + j] >= dp[i * (m + 1) + j + 1]) { i++; }
    else { j++; }
  }
  return map;
}

/** The original with the edit (before -> after) made in it; the original as it is when nothing changed. */
export function mergeEdit(original: string, before: string, after: string): string {
  if (after === before) { return original; }
  const O = original.replace(/\r/g, '').split('\n');
  const A = before.replace(/\r/g, '').split('\n');
  const B = after.replace(/\r/g, '').split('\n');
  // The editor's lines that the edit left (A -> B), and where each non-blank one is in the original (A -> O).
  const ab = lcs(A, B);
  const aIdx = A.map((l, i) => i).filter(i => A[i].trim());
  const oIdx = O.map((l, i) => i).filter(i => O[i].trim());
  const ao0 = lcs(aIdx.map(i => norm(A[i])), oIdx.map(i => norm(O[i])));
  const ao = new Map<number, number>();
  for (const [x, y] of ao0) { ao.set(aIdx[x], oIdx[y]); }
  // The anchors: lines of "before" both left by the edit and found in the original, in order in all three.
  const anchors: [number, number, number][] = [[-1, -1, -1]];
  for (let a = 0; a < A.length; a++) {
    const b = ab.get(a), o = ao.get(a);
    if (b === undefined || o === undefined) { continue; }
    const last = anchors[anchors.length - 1];
    if (b > last[1] && o > last[2]) { anchors.push([a, b, o]); }
  }
  anchors.push([A.length, B.length, O.length]);
  // Between two anchors: the original's lines when the edit left that stretch, else the editor's new ones.
  const out: string[] = [];
  for (let k = 0; k + 1 < anchors.length; k++) {
    const [a1, b1, o1] = anchors[k], [a2, b2, o2] = anchors[k + 1];
    const was = A.slice(a1 + 1, a2), now = B.slice(b1 + 1, b2);
    const orig = O.slice(o1 + 1, o2);
    if (was.length === now.length && was.every((l, i) => l === now[i])) { out.push(...orig); }
    else {
      // What the edit left at the stretch's edges, when only blank lines (the editor's own spacing): the
      // original's spacing there, the edited lines between.
      let p = 0, s = 0;
      while (p < was.length && p < now.length && was[p] === now[p]) { p++; }
      while (s < was.length - p && s < now.length - p && was[was.length - 1 - s] === now[now.length - 1 - s]) { s++; }
      const edges = [...was.slice(0, p), ...was.slice(was.length - s)];
      if (edges.every(l => !l.trim())) {
        let lead = 0, trail = 0;
        while (lead < orig.length && !orig[lead].trim()) { lead++; }
        while (trail < orig.length - lead && !orig[orig.length - 1 - trail].trim()) { trail++; }
        const mid = now.slice(p, now.length - s);
        // A stretch taken out: one gap where it was, not two.
        if (!mid.some(l => l.trim())) { out.push(...orig.slice(0, Math.max(lead, trail))); }
        else { out.push(...orig.slice(0, lead), ...mid, ...orig.slice(orig.length - trail)); }
      }
      else { out.push(...now); }
    }
    if (k + 1 < anchors.length - 1) { out.push(O[o2]); }
  }
  return out.join('\n');
}
