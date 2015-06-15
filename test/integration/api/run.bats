#!/usr/bin/env bats

load ../helpers

function teardown() {
	swarm_manage_cleanup
	stop_docker
}

@test "docker run" {
	start_docker_with_busybox 2
	swarm_manage

	# make sure no container exist
	run docker_swarm ps -qa
	[ "${#lines[@]}" -eq 0 ]

	# run
	docker_swarm run -d --name test_container busybox sleep 100

	# verify, container is running
	[ -n $(docker_swarm ps -q --filter=name=test_container --filter=status=running) ]
}

@test "docker run with resources" {
	start_docker_with_busybox 2
	swarm_manage

	# run
	docker_swarm run -d --name test_container \
			 --add-host=host-test:127.0.0.1 \
			 --cap-add=NET_ADMIN \
			 --cap-drop=MKNOD \
			 --label=com.example.version=1.0 \
			 --read-only=true \
			 --ulimit=nofile=10 \
			 --device=/dev/loop0:/dev/loop0 \
			 --ipc=host \
			 --pid=host \
			 busybox sleep 1000

	# verify, container is running
	[ -n $(docker_swarm ps -q --filter=name=test_container --filter=status=running) ]

	run docker_swarm inspect test_container
	# label
	[[ "${output}" == *"com.example.version"* ]]
	# add-host
	[[ "${output}" == *"host-test:127.0.0.1"* ]]
	# cap-add
	[[ "${output}" == *"NET_ADMIN"* ]]
	# cap-drop
	[[ "${output}" == *"MKNOD"* ]]
	# read-only
	[[ "${output}" == *"\"ReadonlyRootfs\": true"* ]]
	# ulimit
	[[ "${output}" == *"nofile"* ]]
	# device
	[[ "${output}" == *"/dev/loop0"* ]]
	# ipc
	[[ "${output}" == *"\"IpcMode\": \"host\""* ]]
	# pid
	[[ "${output}" == *"\"PidMode\": \"host\""* ]]
}

# TODO do not use fixed values for cpu...
# use values that depend on the machine we are using
@test "docker run no cpushares" {
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

	docker_swarm run --name bar -d -c 1 busybox sh
	run docker_swarm inspect --format='{{.HostConfig.CpuShares}}' bar
	echo $output
	[[ "$output" == "0" ]]
	run docker_swarm inspect --format='{{.HostConfig.CpusetCpus}}' bar
	echo $output
	[[ "$output" == "2" ]]

	run docker_swarm info
	echo $output
	[[ "$output" == *"Reserved CPUs: 3"* ]]

	run docker_swarm run --name baz -d -c 10 busybox sh
	[ "$status" -ne 0 ] # fail if too much resources
}

@test "no share overcome resources" {
	start_docker_with_busybox 1
	swarm_manage

	run docker_swarm run -d -c 10 busybox sh
	[ "$status" -ne 0 ] # fail if too much resources

	docker_swarm run --name bar -d -c 1 busybox sh
	run docker_swarm inspect --format='{{.HostConfig.CpuShares}}' bar
	echo $output
	[[ "$output" == "0" ]]
	run docker_swarm inspect --format='{{.HostConfig.CpusetCpus}}' bar
	echo $output
	[[ "$output" == "0" ]] # occupying first cpusetcpu
}

@test "no cpu reservation on error" {
	start_docker_with_busybox 1
	swarm_manage

	run docker_swarm run --name foo -d busybox sh
	[ "$status" -eq 0 ]
	run docker_swarm run --name foo -c 2 -d busybox sh
	[ "$status" -ne 0 ] # expecting to fail on name conflict...

	run docker_swarm info
	echo $output
	[[ "$output" == *"Reserved CPUs: 0"* ]]
}