// Decides which platform jobs a pull request needs, from the dorny/paths-filter
// outputs of the `ci_*` filters in .github/file-filters.yml.
//
// A changed file that matches no platform filter (Dart code, pubspecs, CI
// config, anything unknown) selects every job, so an unlisted path can never
// skip a test. Files in `ci_ignored` select nothing.

interface Core {
  info(message: string): void;
  setOutput(name: string, value: string): void;
}

const TARGETS_BY_PLATFORM = {
  android: ['android'],
  cocoa: ['ios', 'macos'],
  desktop: ['linux', 'windows'],
  web: ['js', 'wasm'],
};

type Platform = keyof typeof TARGETS_BY_PLATFORM;

const PLATFORMS = Object.keys(TARGETS_BY_PLATFORM) as Platform[];

export interface Selection {
  // True when a change can affect every platform, such as Dart code.
  shared: boolean;
  platforms: Set<Platform>;
}

const EVERYTHING: Selection = { shared: true, platforms: new Set(PLATFORMS) };

export function selectJobs(filterOutputs: Record<string, string>): Selection {
  const files = (filter: string): Set<string> =>
    new Set(JSON.parse(filterOutputs[`ci_${filter}_files`] ?? '[]'));

  const ignored = files('ignored');
  const filesByPlatform = PLATFORMS.map((platform) => [platform, files(platform)] as const);
  const platforms = new Set<Platform>();

  for (const file of files('changed')) {
    if (ignored.has(file)) continue;
    const matched = filesByPlatform.filter(([, platformFiles]) => platformFiles.has(file));
    if (matched.length === 0) return EVERYTHING;
    for (const [platform] of matched) platforms.add(platform);
  }

  return { shared: false, platforms };
}

export function detectChanges({
  core,
  eventName,
  filterOutputs,
}: {
  core: Core;
  eventName: string;
  filterOutputs: Record<string, string>;
}): void {
  // Pushes to main and release branches always run everything.
  const selection = eventName === 'pull_request' ? selectJobs(filterOutputs) : EVERYTHING;
  const targets = PLATFORMS.filter((platform) => selection.platforms.has(platform)).flatMap(
    (platform) => TARGETS_BY_PLATFORM[platform],
  );

  core.setOutput('shared', String(selection.shared));
  for (const platform of PLATFORMS) {
    core.setOutput(platform, String(selection.platforms.has(platform)));
  }
  core.setOutput('flutter_targets', JSON.stringify(targets));
  core.info(`shared=${selection.shared} flutter_targets=${JSON.stringify(targets)}`);
}
