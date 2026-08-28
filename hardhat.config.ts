import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';

const config: HardhatUserConfig = {
	solidity: {
		compilers: [
			{
				version: '0.8.36',
				settings: {
					optimizer: {
						enabled: true,
						runs: 1000,
					},
					evmVersion: 'paris',
				},
			},

			{
				version: '0.8.29',
				settings: {
					evmVersion: 'paris',
					viaIR: true,
				},
			},
		],
	},
};

export default config;
