import Markdown, { type Components } from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkBreaks from 'remark-breaks';

import classes from './MarkdownTextViewer.module.scss';

const REMARK_PLUGINS = [remarkGfm, remarkBreaks];

const MARKDOWN_COMPONENTS: Components = {
  a: ({ node, ...props }) => {
    void node;

    return <a {...props} target="_blank" rel="noopener noreferrer" />;
  },
};

export interface MarkdownTextViewerProps {
  children: string;
}

export const MarkdownTextViewer = ({ children }: MarkdownTextViewerProps) => {
  return (
    <div className={classes.MarkdownTextViewer}>
      <Markdown components={MARKDOWN_COMPONENTS} remarkPlugins={REMARK_PLUGINS}>
        {children}
      </Markdown>
    </div>
  );
};
