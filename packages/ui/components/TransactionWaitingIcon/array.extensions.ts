Array.prototype.hasRegEx = function (string: RegExp) {
  return this.join(" ").search(string) > -1;
};

declare global {
  interface Array<T> {
    _phantom: T;
    hasRegEx(string: RegExp): boolean;
  }
}

export {};
