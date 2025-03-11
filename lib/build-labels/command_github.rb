require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:github] = Class.new do
  def run(builder, params, compose_text)
    builder.oc.vendor = 'GITHUB_SERVER_URL/$GITHUB_TRIGGERING_ACTOR'
    builder.oc.authors = 'GITHUB_SERVER_URL/$GITHUB_TRIGGERING_ACTOR'
    builder.oc.revision = '$GITHUB_SHA'
    # builder.oc['ref.name'] = '$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME'
    builder.oc.source = '$GITHUB_SERVER_URL/$GITHUB_REPOSITORY'
    builder.oc.documentation = '$GITHUB_SERVER_URL/$GITHUB_REPOSITORY'
    builder.oc.licenses = '$GITHUB_SERVER_URL/$GITHUB_REPOSITORY'
    builder.oc.url = '$GITHUB_SERVER_URL/$GITHUB_REPOSITORY'
    # builder.oc.title = '$CI_PROJECT_TITLE'
    # builder.oc.created = '$CI_JOB_STARTED_AT'
    # builder.oc.version = '$CI_COMMIT_REF_NAME' # $CI_COMMIT_TAG

    builder.add_namespace :github, 'com.github.ci'
    builder.github.build_time = "#{Time.now}"
    builder.github.user = '$GITHUB_SERVER_URL/$GITHUB_TRIGGERING_ACTOR'
    # builder.github.email = '$GITLAB_USER_EMAIL'
    # builder.github.tagorbranch = '$CI_COMMIT_REF_NAME'
    builder.github.actionurl = '$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID'
    builder.github.commiturl = '$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/commit/$GITHUB_SHA'
    builder.github.cijoburl = '$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/jobs/$GITHUB_JOB'
    # builder.github.mrurl = '$CI_PROJECT_URL/-/merge_requests/$CI_MERGE_REQUEST_ID'
    # builder.github.tag = '$CI_REGISTRY_IMAGE:$GITHUB_SHA'
    builder.github.commit_branch = '$GITHUB_REF_NAME'
    builder.github.commit_short_sha = '$GITHUB_SHA'
    # builder.github.commit_timestamp = '$CI_COMMIT_TIMESTAMP'
    # builder.github.pipeline_id = '$CI_PIPELINE_ID'
    # builder.github.pipeline_iid = '$CI_PIPELINE_IID'

    # org.opencontainers.image.title BUILDTITLE=$(echo $CI_PROJECT_TITLE | tr " " "_")
    # org.opencontainers.image.description
    # date '+%FT%T%z' | sed -E -n 's/(\+[0-9]{2})([0-9]{2})$/\1:\2/p' #rfc 3339 date
    # org.opencontainers.image.created

  end

  def help = 'Use GitHub CI variables'
end.new


