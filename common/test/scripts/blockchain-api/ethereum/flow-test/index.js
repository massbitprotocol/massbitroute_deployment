import { ethers } from "ethers";
import * as fs from "fs";

const NUMBER_OF_TESTS = process.argv[2];
const MASSBIT_ROUTE_ETHEREUM = process.argv[3];
const ANOTHER_ETHEREUM_PROVIDER = process.argv[4];
const ETHEREUM_NETWORK = process.argv[5];
const REPORT_DIR = process.argv[6];
const ETHEREUM_PRIVATE_KEY = process.argv[7];
const ETHEREUM_EOA_ADDRESS = process.argv[8];

const massbit = new ethers.providers.JsonRpcProvider(
  MASSBIT_ROUTE_ETHEREUM,
  ETHEREUM_NETWORK
);
const anotherProvider = new ethers.providers.JsonRpcProvider(
  ANOTHER_ETHEREUM_PROVIDER,
  ETHEREUM_NETWORK
);
const wallet = new ethers.Wallet(ETHEREUM_PRIVATE_KEY, massbit);
const receiver = ETHEREUM_EOA_ADDRESS;
const summary = [];
const reportPath = `${REPORT_DIR}/ethereum-flow-test.json`;

run();

async function run() {
  for (let i = 1; i <= NUMBER_OF_TESTS; i++) {
    summary.push({
      testIndex: i,
      executedAt: Date(),
      result: [await sendTransaction(), await getLatestBlock()],
    });
  }
  if (!fs.existsSync(reportPath)) {
    fs.writeFileSync(reportPath, "[]", "utf8");
  }
  const file = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  file.push(summary);
  fs.writeFileSync(reportPath, JSON.stringify(file, null, 2), "utf8");
}

async function sendTransaction() {
  const job = [];

  const balance1 = await massbit.getBalance(receiver);
  const balance2 = await anotherProvider.getBalance(receiver);

  const tx = await wallet.sendTransaction({
    to: receiver,
    value: ethers.utils.parseEther("0.0001"),
  });
  await tx.wait();

  const balance3 = await massbit.getBalance(receiver);
  const balance4 = await anotherProvider.getBalance(receiver);

  job.push({
    step: "Compare balance before sending transaction",
    status: balance1.eq(balance2),
    detail: balance1.eq(balance2)
      ? null
      : {
          value: balance1,
          expectedValue: balance2,
        },
  });

  job.push({
    step: "Receive ETH after sending transaction",
    status: balance3.sub(balance1).eq(tx.value),
    detail: balance3.sub(balance1).eq(tx.value)
      ? null
      : {
          value: balance3.sub(balance1),
          expectedValue: tx.value,
        },
  });

  job.push({
    step: "Compare balance after sending transaction",
    status: balance3.eq(balance4),
    detail: balance3.eq(balance4)
      ? null
      : {
          value: balance3,
          expectedValue: balance4,
        },
  });

  return { functionName: "sendTransaction", job };
}

async function getLatestBlock() {
  const job = [];

  const block1 = await massbit.getBlock();
  const block2 = await massbit.getBlock(block1.number);
  const block3 = await massbit.getBlock(block1.hash);
  const block4 = await anotherProvider.getBlock(block1.number);

  const check1 = block1 && block1 !== "null" && block1 !== "undefined";
  job.push({
    step: "Check block data not null",
    status: check1,
    detail: check1
      ? null
      : {
          value: block1,
        },
  });

  const check2 = JSON.stringify(block1) === JSON.stringify(block2);
  job.push({
    step: `Check eth_getBlockByNumber("latest") equal eth_getBlockByNumber(blockNumber)`,
    status: check2,
    detail: check2
      ? null
      : {
          value: block1,
          expectedValue: block2,
        },
  });

  const check3 = JSON.stringify(block1) === JSON.stringify(block3);
  job.push({
    step: `Check eth_getBlockByNumber("latest") equal eth_getBlockByNumber(blockHash)`,
    status: check3,
    detail: check3
      ? null
      : {
          value: block1,
          expectedValue: block3,
        },
  });

  const check4 = JSON.stringify(block1) === JSON.stringify(block4);
  job.push({
    step: `Check Massbit block data equal Infura block data`,
    status: check4,
    detail: check4
      ? null
      : {
          value: block1,
          expectedValue: block4,
        },
  });

  return { functionName: "getLatestBlock", job };
}
