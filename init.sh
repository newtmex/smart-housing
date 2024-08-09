#!/bin/bash

network=$1

yarn deploy --network $network &&
    yarn hardhat deployProject --name UloChukwu --symbol CHK --funding-goal 0.0045 --network $network &&
    yarn hardhat deployProject --name "Ugo Amaka" --symbol UGO --funding-goal 0.045 --network $network
