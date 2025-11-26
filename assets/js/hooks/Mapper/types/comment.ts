export type CommentType = {
  characterEveId: string;
  id: string;
  solarSystemId: number;
  text: string;
  updated_at: string;
};

export type CommentSystem = {
  loading: boolean;
  loaded: boolean;
  comments: CommentType[];
};

export interface UseCommentsData {
  loadComments: (systemId: string) => Promise<void>;
  addComment: (systemId: string, comment: CommentType) => void;
  removeComment: (systemId: string, commentId: string) => void;
  comments: Map<string, CommentSystem>;
  lastUpdateKey: number;
}
