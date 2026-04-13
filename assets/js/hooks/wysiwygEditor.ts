import Quill from "quill";
import TurndownService from "turndown";

const WysiwygEditor = {
  mounted() {
    const view = this as any;
    const editorContainer = view.el.querySelector(".ql-editor-container");
    if (!editorContainer) return;

    const toolbarOptions = [
      ["bold", "italic", "underline", "strike"],
      ["blockquote", "link"],
      [{ list: "ordered" }, { list: "bullet" }],
      [{ header: [1, 2, 3, false] }],
      ["clean"],
    ];

    const quill = new Quill(editorContainer, {
      theme: "snow",
      modules: { toolbar: toolbarOptions },
    });

    const initialContent = editorContainer.getAttribute("data-initial-content");
    if (initialContent) {
      quill.clipboard.dangerouslyPasteHTML(initialContent);
    }

    quill.on("text-change", () => {
      view.pushEvent("content-text-change", { content: quill.getText() });
    });

    view.handleEvent("request_editor_content", () => {
      const html = quill.root.innerHTML;

      if (quill.getText().trim() === "") {
        view.pushEvent("editor_content_markdown", { markdown: "" });
      } else {
        const turndownService = new TurndownService();
        const markdown = turndownService.turndown(html);
        view.pushEvent("editor_content_markdown", { markdown: markdown });
      }
    });
  },
};

export default WysiwygEditor;
