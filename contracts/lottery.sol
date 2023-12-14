// SPDX-License-Identifier: MIT
// Specifies the version of Solidity, using semantic versioning.
pragma solidity >=0.7.3;


// Defines the lottery contract.
contract lottery {

// Specify the lottery format
   struct theLotteryFormat {
        string lotteryTitle;
        bool lotteryTypeIsSingleTicket; // if true, participants can buy only a single ticket;
        uint256 lotteryStartDate;
        uint256 lotteryTicketPrice;
        bool lotteryIsOpen; // if true, participants can start buying tickets
        address lotteryOwner; 
        address payable lotteryManager; // address of the wallet to collect the fees
        address payable[] lotteryParticipant; // for the participants not to be another contract
        mapping (address => bool) lotterySingleParticipant; // track individual participant
    }

// Specify the lottery economics
    uint256 public constant ticketFeeShare = 5; // expressed as percentage
    uint256 public constant firstPrizePotShare = 75; // expressed as percentage
    uint256 public constant secondPrizePotShare = 20; // expressed as percentage
    uint256 public currentPot;
    uint256 private bankedPot;

// Specify the lottery
    theLotteryFormat public myLottery;

// Create a new lottery
    constructor () 
    {
        myLottery.lotteryStartDate = block.timestamp;
        myLottery.lotteryTicketPrice = 1;
        myLottery.lotteryOwner = msg.sender;
        myLottery.lotteryManager = payable(msg.sender);
        myLottery.lotteryIsOpen = false;
        currentPot = 0;
        bankedPot = 0;
    }

// Buy a ticket for for the lottery
    function buyLotteryTicket (
    ) external payable {
            require (block.timestamp > myLottery.lotteryStartDate);

            // check price is correct
            require (msg.value == myLottery.lotteryTicketPrice);

            // check lottery is open for ticket purchase
            require (myLottery.lotteryIsOpen == true);

            // check lottery allows purchasing multiple tickets
            require (myLottery.lotteryTypeIsSingleTicket == false);  

            // update pot value with new ticket purchase
            currentPot = currentPot + msg.value;
            myLottery.lotteryParticipant.push(payable(msg.sender));

            //update mapping for tracking single participants
            myLottery.lotterySingleParticipant [msg.sender] = true;
    }

// Buy a ticket for for the lottery
    function buySingleLotteryTicket (
    ) external payable {
            require (block.timestamp > myLottery.lotteryStartDate);

            // check price is correct
            require (msg.value == myLottery.lotteryTicketPrice);

            // check lottery is open for ticket purchase
            require (myLottery.lotteryIsOpen == true);

            // check lottery is of single ticket purchase type
            require (myLottery.lotteryTypeIsSingleTicket == true); 

            // check if no previous ticket was purchased by the same address
            require ( myLottery.lotterySingleParticipant [msg.sender] == false);

            // update pot value with new ticket purchase
            currentPot = currentPot + msg.value;
            myLottery.lotteryParticipant.push(payable(msg.sender));

            //update mapping for tracking single participants
            myLottery.lotterySingleParticipant [msg.sender] = true;
    }

// Run a new lottery
    function runNewLottery (
        string calldata myLotteryTitle,
        uint256 myLotteryStartDate,
        uint256 myLotteryTicketPrice,
        address payable myLotteryManager,
        bool myLotteryIsSingleTicket
    ) external {
            // check the data
            require (myLotteryTicketPrice > 0);

            // require there is no money in the pot (first distribute existing money, than create new lottery)
            require (currentPot == 0); 
            
            // required update is made by the initial owner
            require (msg.sender ==  myLottery.lotteryOwner); 

            //init the lottery variables
            myLottery.lotteryTitle = myLotteryTitle;
            myLottery.lotteryStartDate = myLotteryStartDate;
            myLottery.lotteryTicketPrice = myLotteryTicketPrice;
            myLottery.lotteryManager = myLotteryManager;
            myLottery.lotteryTypeIsSingleTicket = myLotteryIsSingleTicket;

            // open the lottery for ticket purchase
            myLottery.lotteryIsOpen = true;
    }

// Open/close ticket purchasing
    function openOrCloseLottery (
        bool openMyLottery
        ) external {
            myLottery.lotteryIsOpen = openMyLottery;
        }

// Choose winners (first and second) and send Pot prize and Fees
    function endLotteryAndSendPrize () external {
            //check if there are at least 2 tickets purchased
            require (currentPot >= 2 * myLottery.lotteryTicketPrice);
            
            //check if Lottery Owner calls for the end of the lottery and prize distribution
            require (msg.sender == myLottery.lotteryOwner);
            
            // check ticket purchasing is closed
            require (myLottery.lotteryIsOpen == false);

            // initialize the winners
            address payable firstPrize;
            address payable secondPrize;

            // random select winners
            // first prize
            uint randomNumber;
            randomNumber = uint(keccak256(abi.encodePacked(block.timestamp,msg.sender,block.timestamp)));
            randomNumber = randomNumber % myLottery.lotteryParticipant.length;
            firstPrize = myLottery.lotteryParticipant[randomNumber];

            myLottery.lotteryParticipant[randomNumber] = myLottery.lotteryParticipant[myLottery.lotteryParticipant.length - 1];
            myLottery.lotteryParticipant.pop();

            // second prize
            randomNumber = uint(keccak256(abi.encodePacked(block.timestamp,msg.sender,block.timestamp)));
            randomNumber = randomNumber % myLottery.lotteryParticipant.length;
            secondPrize = myLottery.lotteryParticipant[randomNumber];

            uint256 firstPrizeWinAmount;
            uint256 secondPrizeWinAmount;
            uint256 feeWinAmount; 
            firstPrizeWinAmount = (currentPot / 100) * firstPrizePotShare; 
            secondPrizeWinAmount = (currentPot / 100) * secondPrizePotShare; 
            feeWinAmount = currentPot - (firstPrizeWinAmount + secondPrizeWinAmount);

            // pay winners 
            firstPrize.transfer(firstPrizeWinAmount); 
            secondPrize.transfer(secondPrizeWinAmount); 
            
            // bank the commissionFees
            bankedPot = bankedPot + feeWinAmount;

            // reset lottery
            currentPot = 0;

            // reset the list of participants if lottery was of single ticket purchase type
            if (myLottery.lotteryTypeIsSingleTicket == true)
                {   
                    // reset first prize winner address
                    myLottery.lotterySingleParticipant[address(firstPrize)] = false; 
                    
                    // reset all other participants
                    for (uint i = 0; i < myLottery.lotteryParticipant.length; i++)
                        {
                          myLottery.lotterySingleParticipant[address(myLottery.lotteryParticipant[i])] = false;  
                        }
                }
            
            // delete all other components of the existing lottery
            delete myLottery;
    }

// Collect Fees
    function collectBankedFees () external {
            //check if Lottery Owner calls for the end of the lottery and prize distribution
            require (msg.sender == myLottery.lotteryOwner);

            // pay the manager
           myLottery.lotteryManager.transfer(bankedPot);

            //reset bankedPot
            bankedPot = 0;
    }        
}