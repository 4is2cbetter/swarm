#!/usr/bin/env bats

load ../helpers

function teardown() {
  swarm_manage_cleanup
  stop_docker
}

# this test will pass only using a docker version with a `set' command
# e.g. https://github.com/4is2cbetter/docker/tree/add_set
@test "check set command really sets" {
  start_docker_with_busybox 1
  swarm_manage

  # make sure no container exist
  run docker_swarm ps -qa
  [ "${#lines[@]}" -eq 0 ]

  # running
  docker_swarm run -d -m 1g --name foo busybox sleep 3

  run docker_swarm inspect --format='{{.HostConfig.Memory}}' foo
  [ "$status" -eq 0 ]
  echo "HostConfig.Memory -> "$output
  [[ "${output}" == "1073741824" ]] # 1GB = 2^30B = 1073741824B

  run docker_swarm info
  [ "$status" -eq 0 ]
  echo $output
  [[ "${output}" == *"Reserved Memory: 1 GiB"* ]]

  #setting
  run docker_swarm set -m 2g foo
  [ "$status" -eq 0 ]

  run docker_swarm inspect --format='{{.HostConfig.Memory}}' foo
  [ "$status" -eq 0 ]
  echo "HostConfig.Memory -> "$output
  [[ "${output}" == "2147483648" ]]

  run docker_swarm info
  [ "$status" -eq 0 ]
  echo $output
  [[ "${output}" == *"Reserved Memory: 2 GiB"* ]]
}

@test "check set command doesn't let overcome resources" {
  start_docker_with_busybox 1
  swarm_manage

  # make sure no container exist
  run docker_swarm ps -qa
  [ "${#lines[@]}" -eq 0 ]

  output=$(docker_swarm info | awk '/Reserved Memory/ {print $7}' | awk -F'.' '{print $1}')
  ok_mem=$(($output - 1))
  ko_mem=$(($output + 1))
  output=$(docker_swarm info | awk '/Reserved CPUs/ {print $6}')
  ok_cpus=$(($output - 1))
  ko_cpus=$(($output + 1))

  # running
  docker_swarm run -d -m "${ok_mem}g" --name foo busybox sh
  docker_swarm run -d -c $ok_cpus --name bar busybox sh

  #setting
  run docker_swarm set -m "${ko_mem}g" foo
  echo "set -m ${ko_mem}g foo"
  [ "$status" -ne 0 ]
  [[ "${output}" == *"Cannot exceed resources in setting"* ]]
  run docker_swarm set -c ${ko_cpus} bar
  echo "set -c ${ko_cpus} bar"
  [ "$status" -ne 0 ]
  [[ "${output}" == *"Cannot reserve requested CPUs"* ]]

  #ensure nothing has changed
  run docker_swarm info
  echo $output
  [[ "$output" == *"Reserved Memory: $ok_mem GiB"* ]]
  [[ "$output" == *"Reserved CPUs: $ok_cpus"* ]]
}

@test "set down" {
  start_docker_with_busybox 1
  swarm_manage

  # make sure no container exist
  run docker_swarm ps -qa
  [ "${#lines[@]}" -eq 0 ]

  # TODO use right number of cores...
  run docker_swarm run -d -c 3 --name foo busybox sleep 3
  [ "$status" -eq 0 ]

  run docker_swarm inspect --format='{{.HostConfig.CpusetCpus}}' foo
  echo $output
  [[ "$output" == "0,1,2" ]]
  run docker_swarm set -c 2 foo
  [ "$status" -eq 0 ]
  run docker_swarm inspect --format='{{.HostConfig.CpusetCpus}}' foo
  echo $output
  [[ "$output" == "0,1" || "$output" == "0,2" || "$output" == "1,2" ]]

  run docker_swarm info
  echo $output
  [[ "$output" == *"Reserved CPUs: 2"* ]]
}