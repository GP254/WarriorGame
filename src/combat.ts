/** Combat math and spatial lookup shared by the simulation and tests. */
export type Point = { x: number; z: number };
export function effectiveDamage(raw: number, armor: number, guard = false) {
  return Math.max(1, Math.round((raw - armor * 0.45) * (guard ? 0.17 : 1)));
}
export function meleeInRange(a: Point, b: Point, range: number) {
  return (a.x - b.x) ** 2 + (a.z - b.z) ** 2 <= range * range;
}
export function animationFrame(progress: number) {
  return Math.min(7, Math.max(0, Math.floor(progress * 8)));
}
export class SpatialGrid<T extends Point> {
  private bins = new Map<string, T[]>();
  constructor(public cellSize = 140) {}
  rebuild(items: T[]) {
    this.bins.clear();
    for (const item of items) {
      const key = `${Math.floor(item.x / this.cellSize)},${Math.floor(item.z / this.cellSize)}`;
      const bin = this.bins.get(key);
      if (bin) bin.push(item);
      else this.bins.set(key, [item]);
    }
  }
  near(point: Point, radius: number): T[] {
    const out: T[] = [];
    for (
      let x = Math.floor((point.x - radius) / this.cellSize);
      x <= Math.floor((point.x + radius) / this.cellSize);
      x++
    )
      for (
        let z = Math.floor((point.z - radius) / this.cellSize);
        z <= Math.floor((point.z + radius) / this.cellSize);
        z++
      ) {
        const bin = this.bins.get(`${x},${z}`);
        if (bin)
          for (const item of bin)
            if (meleeInRange(point, item, radius)) out.push(item);
      }
    return out;
  }
}
