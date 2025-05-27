import Markdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkBreaks from 'remark-breaks';

const REMARK_PLUGINS = [remarkGfm, remarkBreaks];

type MarkdownTextViewerProps = { children: string };

export const MarkdownTextViewer = ({ children }: MarkdownTextViewerProps) => {
  return <Markdown remarkPlugins={REMARK_PLUGINS}>{children}</Markdown>;
};
