import { ContextMenu } from 'primereact/contextmenu';

class ContextManager {
  private prev: ContextMenu | null = null;
  private prevId: string | null = null;

  next(id: string | null, ctx: ContextMenu | null) {
    if (id === null && this.prev !== null) {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-expect-error
      this.prev.hide();
      return;
    }

    if (this.prevId === id) {
      return;
    }

    if (this.prev !== null && this.prevId !== id) {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-expect-error
      this.prev.hide();
    }

    this.prev = ctx;
    this.prevId = id;
  }
  reset() {
    if (this.prev != null) {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-expect-error
      this.prev.hide();
    }
  }
}

export const ctxManager = new ContextManager();
