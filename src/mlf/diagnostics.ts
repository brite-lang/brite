const opaque = Symbol();

export type Reported<T> = T & typeof opaque;

export class Diagnostics<T> {
  public static create<T>(): Diagnostics<T> {
    return new Diagnostics();
  }

  private readonly reported: Array<T> = [];

  private constructor() {}

  report(diagnostic: T): Reported<T> {
    this.reported.push(diagnostic);
    return diagnostic as Reported<T>;
  }
}