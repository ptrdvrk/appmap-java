#!/usr/bin/env bats
#
# Runs smoke tests against a Spring sample application available here:
# https://github.com/spring-projects/spring-petclinic
#
# If running locally, keep in mind that this application will cache SQL results,
# likely causing subsequent test runs to fail.

WS_URL=${WS_URL:-http://localhost:8080}

load '../../build/bats/bats-support/load'
load '../../build/bats/bats-assert/load'
load '../helper'

@test "the recording status reports disabled when not recording" {
  run _curl -sXGET "${WS_URL}/_appmap/record"

  assert_success

  assert_json_eq '.enabled' 'false'
}

@test "successfully start a new recording" {
  run _curl -sIXPOST "${WS_URL}/_appmap/record"

  assert_success
  
  echo "${output}" \
    | grep "HTTP/1.1 200"
}

@test "fail to start a recording while recording is already in progress" {
  start_recording
  
  run _curl -sIXPOST "${WS_URL}/_appmap/record"

  assert_success

  echo "${output}" \
    | grep "HTTP/1.1 409"
}

@test "the recording status reports enabled when recording" {
  start_recording
  
  run _curl -sXGET "${WS_URL}/_appmap/record"

  assert_success
  assert_json_eq '.enabled' 'true'
}

@test "grab a checkpoint during remote recording" {
  start_recording

  _curl -XGET "${WS_URL}"

  run _curl -sXGET "${WS_URL}/_appmap/record/checkpoint"

  assert_json '.classMap'
  assert_json '.events'
  assert_json '.version'

  run _curl -sXGET "${WS_URL}/_appmap/record"

  assert_success
  assert_json_eq '.enabled' 'true'

  run _curl -sXDELETE "${WS_URL}/_appmap/record"

  assert_success

  assert_json '.classMap'
  assert_json '.events'
  assert_json '.version'
}

@test "successfully stop the current recording" {
  start_recording
  
  _curl -XGET "${WS_URL}"
  run _curl -sXDELETE "${WS_URL}/_appmap/record"

  assert_success

  assert_json '.classMap'
  assert_json '.events'
  assert_json '.version'
}

@test "recordings capture http request" {
  start_recording
  _curl -XGET "${WS_URL}"
  stop_recording

  assert_json '.events[] | .http_server_request'
}

# NB: Because of the way query results are cached in petclinic, this
# test will only pass the first time it's run.
@test "recordings capture sql queries" {
  start_recording
  _curl -XGET "${WS_URL}/vets.html"
  stop_recording

  assert_json '.events[] | .sql_query'
  assert_json '.events[] | .sql_query.database_type'
}

@test "records exceptions" {
  start_recording
  _curl -XGET "${WS_URL}/oups"
  stop_recording

  assert_json '.events[] | .exceptions'
}

@test "recordings have Java metadata" {
  start_recording
  _curl -XGET "${WS_URL}"
  stop_recording

  eval $(java -cp test/petclinic/classes petclinic.Props java.vm.version java.vm.name)
  assert_json_eq '.metadata.language.name' 'java'
  assert_json_eq '.metadata.language.version' "${JAVA_VM_VERSION}"
  assert_json_eq '.metadata.language.engine' "${JAVA_VM_NAME}"
}

@test "message parameters contain path params from a Spring app" {
  start_recording
  _curl -XGET "${WS_URL}/owners/1/pets/1/edit"
  stop_recording

  assert_json_eq '.events[] | .http_server_request.normalized_path_info' '/owners/:ownerId/pets/:petId/edit'
  assert_json_contains '.events[] | .message' 'ownerId'
  assert_json_contains '.events[] | .message' 'petId'
}

@test "return events have parent_id and don't have non-essential parameters" {
  start_recording
  _curl -XGET "${WS_URL}/owners/1/pets/1/edit"
  stop_recording

  assert_json_not_contains '.events[] | select(.frozen)'
  assert_json_contains '.events[] | select(.event == "call" and .defined_class)'
  assert_json_not_contains '.events[] | select(.event == "return" and .defined_class)'
  assert_json_contains '.events[] | select(.sql_query)'
  assert_json_contains '.events[] | select(.http_server_request)'
  assert_json_contains '.events[] | select(.http_server_response)'
  assert_json_not_contains '.events[] | select(.sql_query and .defined_class)'
  assert_json_not_contains '.events[] | select(.http_server_request and .defined_class)'
  assert_json_not_contains '.events[] | select(.http_server_response and .defined_class)'
}

@test "expected appmap captured" {
  start_recording
  
  # this route seems least likely to be affected by future changes
  _curl -XGET "${WS_URL}/oups"
  
  stop_recording

  # Sanity check the events and classmap
  assert_json_eq '.events | length' 6

  assert_json_eq '.classMap | length' 1
  assert_json_eq '[.classMap[0] | recurse | .name?] | join(".")' org.springframework.samples.petclinic.system.CrashController.triggerException
}
