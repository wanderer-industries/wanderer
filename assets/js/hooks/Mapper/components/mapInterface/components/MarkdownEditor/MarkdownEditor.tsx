import { ReactNode, useCallback, useRef, useState } from 'react';
import CodeMirror, { ViewPlugin } from '@uiw/react-codemirror';
import { markdown } from '@codemirror/lang-markdown';
import { oneDark } from '@codemirror/theme-one-dark';
import { EditorView, type ViewUpdate } from '@codemirror/view';

import classes from './MarkdownEditor.module.scss';
import clsx from 'clsx';

// TODO special plugin which force CodeMirror using capture for paste event
const stopEventPropagationPlugin = ViewPlugin.fromClass(
  class {
    constructor(view: EditorView) {
      // @ts-ignore
      this.view = view;

      // @ts-ignore
      this.pasteHandler = (event: Event) => {
        event.stopPropagation();
      };

      // @ts-ignore
      view.dom.addEventListener('paste', this.pasteHandler);
    }

    destroy() {
      // @ts-ignore
      this.view.dom.removeEventListener('paste', this.pasteHandler);
    }
  },
);

const CODE_MIRROR_EXTENSIONS = [
  markdown(),
  EditorView.lineWrapping,
  EditorView.theme({
    '&': { backgroundColor: 'transparent !important' },
    '& .cm-gutterElement': { display: 'none' },
  }),
  stopEventPropagationPlugin,
];

export interface MarkdownEditorProps {
  overlayContent?: ReactNode;
  value: string;
  onChange: (value: string) => void;
}

export const MarkdownEditor = ({ value, onChange, overlayContent }: MarkdownEditorProps) => {
  const [hasShift, setHasShift] = useState(false);

  const refData = useRef({ onChange });
  refData.current = { onChange };

  const handleOnChange = useCallback((value: string, viewUpdate: ViewUpdate) => {
    // Rerender happens after change
    setTimeout(() => {
      const scrollDOM = viewUpdate.view.scrollDOM;
      setHasShift(scrollDOM.scrollHeight > scrollDOM.clientHeight);
    }, 0);

    refData.current.onChange(value);
  }, []);

  return (
    <div className={clsx(classes.MarkdownEditor, 'relative')}>
      <CodeMirror
        value={value}
        height="70px"
        extensions={CODE_MIRROR_EXTENSIONS}
        className={classes.CERoot}
        theme={oneDark}
        onChange={handleOnChange}
        placeholder="Start typing..."
      />
      <div
        className={clsx('absolute top-0 left-0 h-full pointer-events-none', {
          'w-full': !hasShift,
          'w-[calc(100%-10px)]': hasShift,
        })}
      >
        {overlayContent}
      </div>
    </div>
  );
};
