// Decides which platform jobs a pull request needs, from the dorny/paths-filter
// outputs of the `ci_*` filters in .github/file-filters.yml.
//
// A changed file that matches no platform filter (Dart code, pubspecs, CI
// config, anything unknown) selects every job, so an unlisted path can never
// skip a test. Files in `ci_ignored` select nothing, except that a package
// README or CHANGELOG still runs package analysis, because pana scores them.

interface Core {
  info(message: string): void;
  setOutput(name: string, value: string): void;
}

// sentry-flutter build targets per platform, with the name shown in check names.
const TARGETS_BY_PLATFORM = {
  android: { android: 'Android' },
  cocoa: { ios: 'iOS', macos: 'macOS' },
  desktop: { linux: 'Linux', windows: 'Windows' },
  web: { js: 'Web', wasm: 'Wasm' },
};

type Platform = keyof typeof TARGETS_BY_PLATFORM;

const PLATFORMS = Object.keys(TARGETS_BY_PLATFORM) as Platform[];

export interface Selection {
  // True when a change can affect every platform, such as Dart code.
  shared: boolean;
  // True when package analysis (pana) should run.
  pana: boolean;
  platforms: Set<Platform>;
}

const EVERYTHING: Selection = { shared: true, pana: true, platforms: new Set(PLATFORMS) };

export function selectJobs(filterOutputs: Record<string, string>): Selection {
  // dorny/paths-filter sets `<filter>_files` for every filter, even with no
  // match. A missing one means a filter was renamed or removed, and treating it
  // as empty could skip jobs, so fail instead.
  const files = (filter: string): Set<string> => {
    const output = filterOutputs[`ci_${filter}_files`];
    if (output === undefined) {
      throw new Error(`Missing paths-filter output ci_${filter}_files; check .github/file-filters.yml`);
    }
    return new Set(JSON.parse(output));
  };

  const ignored = files('ignored');
  const pana = files('package_docs').size > 0;
  const filesByPlatform = PLATFORMS.map((platform) => [platform, files(platform)] as const);
  const platforms = new Set<Platform>();

  for (const file of files('changed')) {
    if (ignored.has(file)) continue;
    const matched = filesByPlatform.filter(([, platformFiles]) => platformFiles.has(file));
    if (matched.length === 0) return EVERYTHING;
    for (const [platform] of matched) platforms.add(platform);
  }

  return { shared: false, pana, platforms };
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
    (platform) => Object.entries(TARGETS_BY_PLATFORM[platform]),
  );
  // Matrix `target` and `include` keys for the sentry-flutter build job. Each
  // include entry only adds the display name to a selected target.
  const flutterMatrix = {
    target: targets.map(([target]) => target),
    include: targets.map(([target, name]) => ({ target, platform: name })),
  };

  core.setOutput('shared', String(selection.shared));
  core.setOutput('pana', String(selection.pana));
  for (const platform of PLATFORMS) {
    core.setOutput(platform, String(selection.platforms.has(platform)));
  }
  core.setOutput('flutter_matrix', JSON.stringify(flutterMatrix));
  core.info(`shared=${selection.shared} flutter_matrix=${JSON.stringify(flutterMatrix)}`);
}
