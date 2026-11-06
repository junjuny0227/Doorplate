import type { ReactNode } from 'react';

// SF Symbol-like glyphs drawn inline (no icon package, no SF Symbols). All are decorative: the
// element that uses them carries the accessible name. Same tile and glyph style as Repot's site
// (apps/site/src/icons.tsx); the Doorplate glyphs are original.

export type FeatureKey =
  | 'names'
  | 'docker'
  | 'noise'
  | 'system'
  | 'stop'
  | 'live'
  | 'updates'
  | 'languages';
export type PrincipleKey = 'local' | 'admin' | 'network' | 'telemetry';
export type StackKey = 'node' | 'jvm' | 'rust' | 'python' | 'ruby' | 'docker';
export type TileKey = FeatureKey | PrincipleKey | StackKey;

const stroke = {
  fill: 'none',
  stroke: '#fff',
  strokeWidth: 1.3,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
} as const;

const GLYPHS: Record<TileKey, ReactNode> = {
  // a nameplate with two lines of text
  names: (
    <g {...stroke}>
      <rect x="2.4" y="4.4" width="11.2" height="7.2" rx="1.6" />
      <path d="M5 7.1h6M5 9.1h3.6" />
    </g>
  ),
  // a container
  docker: (
    <g {...stroke}>
      <path d="M8 2.6l5 2.5v5.8L8 13.4l-5-2.5V5.1z" />
      <path d="M3 5.1l5 2.5 5-2.5M8 7.6v5.8" />
    </g>
  ),
  // eye with a slash: hidden rows
  noise: (
    <g {...stroke}>
      <path d="M2.2 8c1.4-2.5 3.4-3.8 5.8-3.8s4.4 1.3 5.8 3.8c-1.4 2.5-3.4 3.8-5.8 3.8S3.6 10.5 2.2 8z" />
      <circle cx="8" cy="8" r="1.7" />
      <path d="M3.2 12.8l9.6-9.6" />
    </g>
  ),
  // information
  system: (
    <g {...stroke}>
      <circle cx="8" cy="8" r="5.6" />
      <path d="M8 7.4v3.6" />
      <circle cx="8" cy="5.2" r="0.4" fill="#fff" />
    </g>
  ),
  // stop
  stop: (
    <g {...stroke}>
      <circle cx="8" cy="8" r="5.6" />
      <rect x="5.9" y="5.9" width="4.2" height="4.2" rx="0.8" fill="#fff" />
    </g>
  ),
  // clock: how long a server has run
  live: (
    <g {...stroke}>
      <circle cx="8" cy="8" r="5.6" />
      <path d="M8 4.8V8l2.3 1.5" />
    </g>
  ),
  // arrow into a tray: an update
  updates: (
    <g {...stroke}>
      <path d="M8 2.6v7M5.2 6.9L8 9.7l2.8-2.8" />
      <path d="M3 10.2v1.6a1.4 1.4 0 0 0 1.4 1.4h7.2a1.4 1.4 0 0 0 1.4-1.4v-1.6" />
    </g>
  ),
  // globe
  languages: (
    <g {...stroke} strokeWidth={1.2}>
      <circle cx="8" cy="8" r="5.4" />
      <ellipse cx="8" cy="8" rx="2.3" ry="5.4" />
      <path d="M2.6 8h10.8" />
    </g>
  ),
  // laptop: everything happens on this Mac
  local: (
    <g {...stroke}>
      <rect x="3.2" y="3.6" width="9.6" height="6.6" rx="1" />
      <path d="M1.8 12.4h12.4" />
    </g>
  ),
  // shield: no administrator rights
  admin: (
    <g {...stroke}>
      <path d="M8 2.4l4.6 1.8v3.6c0 2.9-2 4.9-4.6 5.8-2.6-.9-4.6-2.9-4.6-5.8V4.2z" />
      <path d="M6 8l1.5 1.5L10.2 6.7" />
    </g>
  ),
  // wifi with a slash: no network but updates
  network: (
    <g {...stroke}>
      <path d="M2.4 6.6a8 8 0 0 1 11.2 0M4.4 8.8a5.2 5.2 0 0 1 7.2 0M6.4 11a2.3 2.3 0 0 1 3.2 0" />
      <path d="M3.2 13.2l9.6-10.4" />
    </g>
  ),
  // chart with a slash: no statistics
  telemetry: (
    <g {...stroke}>
      <path d="M4 12.6V9.4M8 12.6V5.8M12 12.6V7.8" />
      <path d="M2.8 3.2l10.4 10" />
    </g>
  ),
  // hexagon
  node: (
    <g {...stroke}>
      <path d="M8 2.4l4.8 2.8v5.6L8 13.6l-4.8-2.8V5.2z" />
    </g>
  ),
  // cup
  jvm: (
    <g {...stroke}>
      <path d="M3.4 6.4h7v3.2a3.5 3.5 0 0 1-7 0z" />
      <path d="M10.4 7.2h.9a1.4 1.4 0 0 1 0 2.8h-1.1M5.6 2.8v1.8M8.2 2.8v1.8" />
    </g>
  ),
  // gear
  rust: (
    <g {...stroke}>
      <circle cx="8" cy="8" r="2" />
      <path d="M8 2.6v1.8M8 11.6v1.8M2.6 8h1.8M11.6 8h1.8M4.2 4.2l1.3 1.3M10.5 10.5l1.3 1.3M4.2 11.8l1.3-1.3M10.5 5.5l1.3-1.3" />
    </g>
  ),
  // braces
  python: (
    <g {...stroke}>
      <path d="M6 3.2c-1.3 0-1.8.6-1.8 1.8v1.3c0 .9-.5 1.7-1.4 1.7.9 0 1.4.8 1.4 1.7V11c0 1.2.5 1.8 1.8 1.8M10 3.2c1.3 0 1.8.6 1.8 1.8v1.3c0 .9.5 1.7 1.4 1.7-.9 0-1.4.8-1.4 1.7V11c0 1.2-.5 1.8-1.8 1.8" />
    </g>
  ),
  // gem
  ruby: (
    <g {...stroke}>
      <path d="M4.6 3.4h6.8l2.2 2.9L8 12.8 2.4 6.3z" />
      <path d="M2.4 6.3h11.2M6.4 3.4L5.6 6.3 8 12.8l2.4-6.5-.8-2.9" />
    </g>
  ),
};

export function SymbolTile({ name }: { name: TileKey }) {
  return (
    <span className={`tile tile-${name}`} aria-hidden="true">
      <svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">
        {GLYPHS[name]}
      </svg>
    </span>
  );
}

export const WarningTriangle = () => (
  <svg className="symbol" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
    <path
      d="M6.9 2.1a1.27 1.27 0 0 1 2.2 0l5.6 9.9a1.27 1.27 0 0 1-1.1 1.9H2.4a1.27 1.27 0 0 1-1.1-1.9z"
      fill="currentColor"
    />
    <path d="M8 5.6v3.5" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" />
    <circle cx="8" cy="11.4" r="0.85" fill="#fff" />
  </svg>
);

export const DownloadArrow = () => (
  <svg className="symbol" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
    <path
      d="M8 2.5v8M4.6 7.4L8 10.8l3.4-3.4M3 13.2h10"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const Globe = () => (
  <svg className="symbol" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
    <circle cx="8" cy="8" r="6.4" fill="none" stroke="currentColor" strokeWidth="1.2" />
    <ellipse cx="8" cy="8" rx="2.7" ry="6.4" fill="none" stroke="currentColor" strokeWidth="1.1" />
    <path
      d="M1.8 8h12.4M2.9 4.8h10.2M2.9 11.2h10.2"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.1"
    />
  </svg>
);

export const CopyGlyph = () => (
  <svg className="symbol" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
    <g fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round">
      <rect x="5.4" y="5.4" width="8" height="8" rx="1.6" />
      <path d="M10.6 5.4V4a1.4 1.4 0 0 0-1.4-1.4H4a1.4 1.4 0 0 0-1.4 1.4v5.2A1.4 1.4 0 0 0 4 10.6h1.4" />
    </g>
  </svg>
);

export const Checkmark = () => (
  <svg className="symbol" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
    <path
      d="M3.4 8.4l3 3 6.2-6.8"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
