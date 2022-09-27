import yargs from 'yargs/yargs';
import { hideBin } from 'yargs/helpers';

import {UpgradeManager__factory} from '../../build/typechain/factories';

function run(data) {
  Manager__factory.connect()
}

yargs(hideBin(process.argv))
  .command('bid [tokenid]', 'place bid', (yargs) => {
    return yargs
      .positional('tokenid', {
        describe: 'token id to bid on'
      })
  }, (argv) => {
    run(argv)
  })
  .option('verbose', {
    alias: 'v',
    type: 'boolean',
    description: 'Run with verbose logging'
  })
  .parse()