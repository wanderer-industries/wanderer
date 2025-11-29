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
  loadComments: (systemId: number) => Promise<void>;
  addComment: (systemId: number, comment: CommentType) => void;
  removeComment: (systemId: number, commentId: string) => void;
  comments: Map<number, CommentSystem>;
  lastUpdateKey: number;
}
