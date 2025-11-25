import Markdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkBreaks from 'remark-breaks';

import classes from './MarkdownTextViewer.module.scss';

const REMARK_PLUGINS = [remarkGfm, remarkBreaks];

type MarkdownTextViewerProps = { children: string };

export const MarkdownTextViewer = ({ children }: MarkdownTextViewerProps) => {
  return (
    <div className={classes.MarkdownTextViewer}>
      <Markdown remarkPlugins={REMARK_PLUGINS}>{children}</Markdown>
    </div>
  );
};
