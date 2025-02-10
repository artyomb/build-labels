require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:gitlab] = Class.new do
  def run(builder, params, compose_text)
    builder.oc.vendor = '$CI_SERVER_URL/$GITLAB_USER_LOGIN'
    builder.oc.authors = '$CI_SERVER_URL/$GITLAB_USER_LOGIN'
    builder.oc.revision = '$CI_COMMIT_SHA'
    builder.oc['ref.name'] = '$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME'
    builder.oc.source = '$CI_PROJECT_URL'
    builder.oc.documentation = '$CI_PROJECT_URL'
    builder.oc.licenses = '$CI_PROJECT_URL'
    builder.oc.url = '$CI_PROJECT_URL'
    builder.oc.title = '$CI_PROJECT_TITLE'
    builder.oc.created = '$CI_JOB_STARTED_AT'
    builder.oc.version = '$CI_COMMIT_REF_NAME' # $CI_COMMIT_TAG

    builder.add_namespace :gitlab, 'com.gitlab.ci'
    builder.gitlab.user = '$CI_SERVER_URL/$GITLAB_USER_LOGIN'
    builder.gitlab.email = '$GITLAB_USER_EMAIL'
    builder.gitlab.tagorbranch = '$CI_COMMIT_REF_NAME'
    builder.gitlab.pipelineurl = '$CI_PIPELINE_URL'
    builder.gitlab.commiturl = '$CI_PROJECT_URL/commit/$CI_COMMIT_SHA'
    builder.gitlab.cijoburl = '$CI_JOB_URL'
    builder.gitlab.mrurl = '$CI_PROJECT_URL/-/merge_requests/$CI_MERGE_REQUEST_ID'
    builder.gitlab.tag = '$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA'
    builder.gitlab.commit_branch = '$CI_COMMIT_BRANCH'
    builder.gitlab.commit_short_sha = '$CI_COMMIT_SHORT_SHA'
    builder.gitlab.commit_timestamp = '$CI_COMMIT_TIMESTAMP'
    builder.gitlab.pipeline_id = '$CI_PIPELINE_ID'
    builder.gitlab.pipeline_iid = '$CI_PIPELINE_IID'

    # org.opencontainers.image.title BUILDTITLE=$(echo $CI_PROJECT_TITLE | tr " " "_")
    # org.opencontainers.image.description
    # date '+%FT%T%z' | sed -E -n 's/(\+[0-9]{2})([0-9]{2})$/\1:\2/p' #rfc 3339 date
    # org.opencontainers.image.created

  end

  def help = 'Use GitLab CI variables'
end.new


