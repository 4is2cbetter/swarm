#!/usr/bin/env bats

load ../helpers

function teardown() {
	swarm_manage_cleanup
	stop_docker
}

@test "docker rm" {
	start_docker_with_busybox 2
	swarm_manage

	docker_swarm create --name test_container busybox
	
	# make sure container exsists
	run docker_swarm ps -l
	[ "${#lines[@]}" -eq 2 ]
	[[ "${lines[1]}" == *"test_container"* ]]

	docker_swarm rm test_container
	
	# verify
	run docker_swarm ps -aq
	[ "${#lines[@]}" -eq 0 ]
}

@test "docker rm -f" {
	start_docker_with_busybox 2
	swarm_manage

	docker_swarm run -d --name test_container busybox sleep 500

	# make sure container exsists and is up
	[ -n $(docker_swarm ps -q --filter=name=test_container --filter=status=running) ]

	# rm, remove a running container, return error
	run docker_swarm rm test_container
	[ "$status" -ne 0 ]

	# rm -f, remove a running container
	docker_swarm rm -f test_container

	# verify
	run docker_swarm ps -aq
	[ "${#lines[@]}" -eq 0 ]
}

@test "cpu reservation update on remove" {
	start_docker_with_busybox 1
	swarm_manage

	# make sure no container exist
	run docker_swarm ps -qa
	[ "${#lines[@]}" -eq 0 ]

	docker_swarm run --name foo -d -c 2 busybox sh

	run docker_swarm inspect --format='{{.HostConfig.CpuShares}}' foo
	echo $output
	[[ "$output" == "0" ]]
	run docker_swarm inspect --format='{{.HostConfig.CpusetCpus}}' foo
	echo $output
	[[ "$output" == "0,1" ]]

	docker_swarm rm -f foo
	docker_swarm run --name foo -d -c 1 busybox sh

	run docker_swarm inspect --format='{{.HostConfig.CpuShares}}' foo
	echo $output
	[[ "$output" == "0" ]]
	run docker_swarm inspect --format='{{.HostConfig.CpusetCpus}}' foo
	echo $output
	[[ "$output" == "0" ]]
}
