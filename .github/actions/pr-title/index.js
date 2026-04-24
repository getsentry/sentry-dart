module.exports = async ({ github, context, core }) => {
  function isRevert(title) {
    const REVERT_RE = /^Revert ".*"$/;
    return title && title.match(REVERT_RE) !== null;
  }

  async function checkPrTitle(pr) {
    // Opt-out label for rare cases.
    const hasIgnoreLabel = (pr.labels || []).some(label => label.name === 'ignore-title');
    if (hasIgnoreLabel) {
      return;
    }

    // From: <https://develop.sentry.dev/engineering-practices/commit-messages/>.
    const TITLE_RE = /^(ci|build|docs|feat|fix|perf|ref|style|chore|test|meta|license)(\([^)]+\))?: [A-Z`'"].*[^,.]$/;

    if (pr.title.match(TITLE_RE) === null && !isRevert(pr.title)) {
      core.setFailed('PR title does not match Sentry conventions.');
      core.info('Please follow the Sentry commit message conventions: https://develop.sentry.dev/engineering-practices/commit-messages/');
      core.info('');
      core.info('Format: <type>(<scope>): <subject>');
      core.info('Subject line must be capitalized and must not end with a period.');
      return;
    }

    core.info("PR title matches Sentry conventions!");
  }

  async function checkAll() {
    const { data: pr } = await github.rest.pulls.get({
      owner: context.repo.owner,
      repo: context.repo.repo,
      pull_number: context.payload.pull_request.number,
    });

    if (pr.merged || pr.draft) {
      return;
    }

    await checkPrTitle(pr);
  }

  await checkAll();
};
