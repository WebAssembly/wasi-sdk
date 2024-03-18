# Release Process

To publish a new version of `wasi-sdk` as a GitHub release:

1. Tag a commit with an annotated tag. Note that this must be an annotated tag,
   not a lightweight tag, so that `version.py` can use it for calculating the
   package version (use `git show wasi-sdk-...` to show other tag messages).
   Note that you may need to clear the repository cache to avoid problems with
   cached artifacts [^cache].

   ```shell script
   TAG=wasi-sdk-1
   git tag -a $TAG
   git push origin $TAG
   ```

2. Find a successful workflow that CI has run for the tag. That successful
   workflow run will have build artifacts that need to be attached to the
   release. One could search around in the GitHub [actions], but the following
   script will list completed workflows for a tag (get a token [here][tokens]):

   ```shell script
   ci/get-workflows-for-tag.sh $TAG $GITHUB_TOKEN
   ```

   [actions]: https://github.com/WebAssembly/wasi-sdk/actions
   [tokens]: https://github.com/settings/tokens

3. Check that the workflow built the artifacts for the given tag and that the
   workflow completed successfully:

   ```shell script
   ci/is-workflow-valid.sh $TAG $WORKFLOW_RUN_ID $GITHUB_TOKEN
   ```

4. Download and unzip the workflow artifacts. Note that artifacts with `+m` or
   `.m` suffixes indicate that the Git tree was modified. Expect some duplicates
   since some of the same artifacts are built on multiple CI runners (e.g.,
   Windows, MacOS, Linux). The following script does all of this automatically:

   ```shell script
   ci/download-workflow-artifacts.sh $WORKFLOW_RUN_ID $GITHUB_TOKEN
   ```

5. Draft a new release. This could be done [manually][releases] but the
   following script simplifies the uploading of all the files and auto-generates
   the release description:

   ```shell script
   ci/draft-release.sh $TAG $ARTIFACTS_DIR $GITHUB_TOKEN
   ```

  [releases]: https://github.com/WebAssembly/wasi-sdk/releases

6. Publish the release; the previous step only creates a draft. Follow the link
   in the previous step or navigate to the GitHub [releases] to review the
   description, commit, tag, and assets before clicking "Publish."

7. Remember to tag the wasi-libc repository with the new `$TAG` version.

   ```shell script
   git submodule status -- src/wasi-libc  # grab $WASI_LIBC_COMMIT from the output
   cd $WASI_LIBC_REPO_DIR
   git tag $TAG $WASI_LIBC_COMMIT
   git push origin $TAG
   ```

[^cache]: Here is an example of how to clear a cache with the GitHub CLI:

    ```shell script
    URL=/repos/WebAssembly/wasi-sdk/actions/caches
    gh api $URL -q '.actions_caches[].id' \
       | xargs -I {} gh api --method DELETE $URL/{}
    ```
