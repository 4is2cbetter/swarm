package strategy

import (
	"github.com/docker/swarm/cluster"
	"github.com/docker/swarm/scheduler/node"
)

// WeightedNode represents a node in the cluster with a given weight, typically used for sorting
// purposes.
type weightedNode struct {
	Node *node.Node
	// Weight is the inherent value of this node.
	Weight int64
}

type weightedNodeList []*weightedNode

func (n weightedNodeList) Len() int {
	return len(n)
}

func (n weightedNodeList) Swap(i, j int) {
	n[i], n[j] = n[j], n[i]
}

func (n weightedNodeList) Less(i, j int) bool {
	var (
		ip = n[i]
		jp = n[j]
	)

	return ip.Weight < jp.Weight
}

func weighNodes(config *cluster.ContainerConfig, nodes []*node.Node) (weightedNodeList, error) {
	weightedNodes := weightedNodeList{}
	nCpus := int64(config.NCpus())
	mem := int64(config.Memory)

	for _, node := range nodes {
		nodeMemory := node.TotalMemory
		nodeCpus := node.TotalCpus

		// Skip nodes that are smaller than the requested resources.
		if nodeMemory < mem || nodeCpus < nCpus {
			continue
		}

		var (
			cpuScore    int64 = 100
			memoryScore int64 = 100
		)

		if nCpus > 0 {
			cpuScore = (node.UsedCpus + nCpus) * 100 / nodeCpus
		}
		if mem > 0 {
			memoryScore = (node.UsedMemory + mem) * 100 / nodeMemory
		}

		if cpuScore <= 100 && memoryScore <= 100 {
			weightedNodes = append(weightedNodes, &weightedNode{Node: node, Weight: cpuScore + memoryScore})
		}
	}

	if len(weightedNodes) == 0 {
		return nil, ErrNoResourcesAvailable
	}

	return weightedNodes, nil
}
