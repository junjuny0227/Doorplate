// Doorplate's captures are dark menus on a transparent background with the macOS menu shadow
// baked in, so they are shown as-is in both color schemes (Repot swaps light and dark captures).
import { BASE } from '../i18n';

export const SHOTS = {
  menu: { width: 565, height: 516 },
  submenu: { width: 914, height: 516 },
  docker: { width: 785, height: 516 },
} as const;

export function Screenshot({
  name,
  alt,
  eager = false,
}: {
  name: keyof typeof SHOTS;
  alt: string;
  eager?: boolean;
}) {
  const { width, height } = SHOTS[name];
  return (
    <picture className="screenshot baked">
      <img
        src={`${BASE}generated/${name}.png`}
        width={width}
        height={height}
        alt={alt}
        loading={eager ? 'eager' : 'lazy'}
        decoding="async"
        fetchPriority={eager ? 'high' : 'auto'}
      />
    </picture>
  );
}
