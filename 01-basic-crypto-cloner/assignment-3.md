# Permanent Evaluation 3: Distributed cloner with reporter

## Sample flow of application

* Node 1 is started //
* Node 1 detects no other nodes and starts cloning //
* Node 2 is started //
* Node 2 detects other nodes and it doesn't start cloning automatically //
* Node 3 is started //
* Node 3 detects other nodes and it doesn't start cloning automatically //
* Node 2 starts balancing //
* Node 2 asks node 1 to transfer N currency pairs to node 3 //
* Node 2 asks node 1 to transfer N currency pairs to node 2 //
* Reporter is started
* Every 10 seconds output is printed on that node's CLI
* Node 3 quits and N currency pairs are lost //
* Node 2 starts balancing //
* Node 2 detects that not all currency pairs are being cloned, and starts processes the missing currency pairs //
* Node 2 asks Node X to transfer N currency pairs to node X //

## Reporter Application

This is a simple application with no globally registered processes. It has one `GenServer` that runs the necessary code every 10 seconds to print out the status of the whole distributed application.

I'm expecting easy to read,  **sorted** (based on %) output such as:

```text
NODE | COIN     | PROGRESS (20chars)   | PROGRESS % | # of entries
##################################################################
N1   | USDT_BTC | ___________________+ | 5%         | 900
N2   | USDT_XMR | __________________++ | 10%        | 500
N4   | ...      | _____________+++++++ | 35%        | 20
N3   | ...      | __________++++++++++ | 50%        | 60
N4   | ...      | ++++++++++++++++++++ | 100%       | 40
N2   | ...      | ++++++++++++++++++++ | 100%       | 112
```

## Requirements
