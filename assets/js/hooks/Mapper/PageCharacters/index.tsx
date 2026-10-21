import { createRoot, Root } from 'react-dom/client';
import { PageCharactersRoot } from './PageCharactersRoot';
import type { PageCharactersEventRef, PageCharactersHooks } from './types';
import { PageCharactersOutCommand } from './types';

interface PageCharactersLiveHook {
  el: HTMLElement;
  pageCharactersRoot?: Root;
  pageCharactersHooks?: PageCharactersHooks;
  pushEvent(event: string, payload: Record<string, unknown>, callback?: (reply: unknown) => void): void;
  handleEvent<T>(event: string, handler: (payload: T) => void): PageCharactersEventRef;
  removeHandleEvent(ref: PageCharactersEventRef): void;
}

const createHooks = (hook: PageCharactersLiveHook): PageCharactersHooks => ({
  handleEvent: hook.handleEvent.bind(hook),
  removeHandleEvent: hook.removeHandleEvent.bind(hook),
  pushEventAsync: <T,>(event: string, payload: Record<string, unknown>) =>
    new Promise<T>(resolve => {
      hook.pushEvent(event, payload, reply => resolve(reply as T));
    }),
});

const PageCharactersHook = {
  mounted(this: PageCharactersLiveHook) {
    this.pageCharactersHooks = createHooks(this);
    this.pageCharactersRoot = createRoot(this.el);
    this.pageCharactersRoot.render(<PageCharactersRoot hooks={this.pageCharactersHooks} />);
  },

  reconnected(this: PageCharactersLiveHook) {
    this.pushEvent(PageCharactersOutCommand.init, {});
  },

  destroyed(this: PageCharactersLiveHook) {
    this.pageCharactersRoot?.unmount();
  },
};

export default PageCharactersHook;
