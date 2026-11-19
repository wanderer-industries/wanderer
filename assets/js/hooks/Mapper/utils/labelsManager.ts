export type LabelsType = {
  customLabel: string;
  labels: string[];
  drifterOut?: boolean;
};

export class LabelsManager {
  protected labelsRaw: string;
  protected parsedLabels: LabelsType = {
    labels: [],
    customLabel: '',
    drifterOut: false,
  };
  constructor(labels: string) {
    this.labelsRaw = labels;
    this.parsedLabels = this.parse();
  }

  parse(): LabelsType {
    try {
      const parsed = JSON.parse(this.labelsRaw);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return {
          customLabel: typeof parsed.customLabel === 'string' ? parsed.customLabel : '',
          labels: Array.isArray(parsed.labels) ? parsed.labels.filter(Boolean) : [],
          drifterOut: Boolean(parsed.drifterOut),
        };
      }
    } catch (err) {
      // Fallback for empty or legacy comma-separated labels
    }

    return {
      customLabel: '',
      labels: this.labelsRaw ? this.labelsRaw.split(',').filter(Boolean) : [],
      drifterOut: false,
    };
  }

  parse2(): LabelsType {
    if (this.labelsRaw.length === 0) {
      return {
        labels: [],
        customLabel: '',
        drifterOut: false,
      };
    }

    const [labels, customLabel] = this.labelsRaw.split(':');
    return {
      labels: labels.split(','),
      customLabel: customLabel ?? '',
      drifterOut: false,
    };
  }

  toString() {
    return JSON.stringify(this.parsedLabels);
  }

  toString2() {
    return `${this.parsedLabels.labels.join(',')}`;
  }

  valueOf() {
    return this.toString();
  }

  updateCustomLabel(label: string) {
    this.parsedLabels.customLabel = label;
  }

  addLabels(labels: string[]) {
    this.parsedLabels.labels = [...new Set([...this.parsedLabels.labels, ...labels])];
  }

  delLabels(labels: string[]) {
    this.parsedLabels.labels = this.parsedLabels.labels.filter(x => !labels.includes(x));
  }

  hasLabel(label: string) {
    return this.parsedLabels.labels?.includes(label);
  }

  toggleLabel(label: string) {
    if (this.parsedLabels.labels.includes(label)) {
      this.delLabels([label]);
    } else {
      this.addLabels([label]);
    }
  }

  clearLabels() {
    this.parsedLabels.labels = [];
  }

  toggleDrifterOut() {
    this.parsedLabels.drifterOut = !this.parsedLabels.drifterOut;
  }

  get drifterOut() {
    return Boolean(this.parsedLabels.drifterOut);
  }

  get customLabel() {
    return this.parsedLabels.customLabel;
  }

  get list() {
    return this.parsedLabels.labels;
  }
}
