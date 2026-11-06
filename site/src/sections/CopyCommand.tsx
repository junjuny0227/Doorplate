import { useState } from 'react';
import type { Messages } from '../i18n';
export function CopyCommand({ command, c }: { command: string; c: Messages }) {
  const [status, setStatus] = useState<'idle' | 'copied' | 'failed'>('idle');
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(command);
      setStatus('copied');
    } catch {
      setStatus('failed');
    }
  };
  return (
    <div className="command-wrap">
      <div className="command">
        <code>{command}</code>
        <button type="button" onClick={copy}>
          {status === 'copied' ? c.ui.copied : c.ui.copy}
        </button>
      </div>
      <p className="copy-status" role="status">
        {status === 'copied' ? c.ui.copied : status === 'failed' ? c.ui.copyFailed : ''}
      </p>
    </div>
  );
}
