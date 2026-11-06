// project.yml remains the only source for app version and download filenames.
export function marketingVersion(project: string): string {
  const version = project.match(/^\s+MARKETING_VERSION:\s*["']?(\d+\.\d+\.\d+)["']?\s*$/m)?.[1];
  if (!version) throw new Error('Missing or invalid MARKETING_VERSION in project.yml');
  return version;
}
export const REPO = 'https://github.com/junjuny0227/Doorplate';
export const BREW = 'brew install --cask junjuny0227/tap/doorplate';
export const downloadUrl = (version: string) =>
  `${REPO}/releases/download/v${version}/Doorplate-${version}.zip`;
