/**
 *Submitted for verification at BscScan.com on 2021-11-12
*/

// SPDX-License-Identifier: MIT

contract Morebnb {
	using SafeMath for uint256;
	
    uint256 constant public INVEST_MIN_AMOUNT = 5e16; // 0.05 bnb
    uint256 constant public WITHDRAW_MAX_PER_DAY_AMOUNT = 50e18; // 50 bnb per day
	uint256[] public REFERRAL_PERCENTS = [70, 30, 15, 10, 5];
	uint256 constant public PROJECT_FEE = 120;
	uint256 constant public DEV_FEE = 30;
	uint256 constant public PERCENT_STEP = 5;
	uint256 constant public PERCENTS_DIVIDER = 1000;
	uint256 constant public TIME_STEP = 1 days;

	uint256 public totalInvested;
	uint256 public totalRefBonus;

    struct Plan {
        uint256 time;
        uint256 percent;
    }

    Plan[] internal plans;

	struct Deposit {
        uint8 plan;
		uint256 amount;
		uint256 start;
	}

	struct User {
		Deposit[] deposits;
		uint256 checkpoint;
		address referrer;
		uint256[5] levels;
		uint256 bonus;
		uint256 totalBonus;
		uint256 withdrawn;
        uint256 firstwithdrawntime;
        uint256 daywithdrawnamount;
	}

	mapping (address => User) internal users;

	bool public started;
	address payable public feeWallet;
    address payable private devWallet;

	event Newbie(address user);
	event NewDeposit(address indexed user, uint8 plan, uint256 amount);
    event ReInvest(address indexed user, uint8 plan, uint256 amount);
	event Withdrawn(address indexed user, uint256 amount);
	event RefBonus(address indexed referrer, address indexed referral, uint256 indexed level, uint256 amount);
	event FeePayed(address indexed user, uint256 totalAmount);
    event SwapETHForTokens(uint256 amountIn, address[] path);
    event SwapAndLiquify(uint256 ethSwapped, uint256 tokenReceived, uint256 ethsIntoLiqudity);
    event FeeWalletUpdated(address indexed oldFeeWallet, address indexed newFeeWallet);
    event DevWalletUpdated(address indexed oldDevWallet, address indexed newDevWallet);

	constructor(address payable wallet, address payable dev) {
		require(!isContract(wallet));
		feeWallet = wallet;
        require(!isContract(dev));
        devWallet = dev;

        plans.push(Plan(15, 80));
        plans.push(Plan(30, 56));
        plans.push(Plan(60, 38));
		plans.push(Plan(90, 33));
		plans.push(Plan(180, 30));
	}

    receive() external payable {

  	}

	function invest(address referrer, uint8 plan) public payable {
		if (!started) {
			if (msg.sender == feeWallet) {
				started = true;
			} else revert("Not started yet");
		}

		require(msg.value >= INVEST_MIN_AMOUNT);
        require(plan < 5, "Invalid plan");
        
		uint256 fee = msg.value.mul(PROJECT_FEE).div(PERCENTS_DIVIDER);
        feeWallet.transfer(fee);
        uint256 devfee = msg.value.mul(DEV_FEE).div(PERCENTS_DIVIDER);
        devWallet.transfer(devfee);

		emit FeePayed(msg.sender, fee.add(devfee));

		User storage user = users[msg.sender];

		if (user.referrer == address(0)) {
			if (users[referrer].deposits.length > 0 && referrer != msg.sender) {
				user.referrer = referrer;
			}

			address upline = user.referrer;
			for (uint256 i = 0; i < 5; i++) {
				if (upline != address(0)) {
					users[upline].levels[i] = users[upline].levels[i].add(1);
					upline = users[upline].referrer;
				} else break;
			}
		}

		if (user.referrer != address(0)) {
			address upline = user.referrer;
			for (uint256 i = 0; i < 5; i++) {
				if (upline != address(0)) {
					uint256 amount = msg.value.mul(REFERRAL_PERCENTS[i]).div(PERCENTS_DIVIDER);
					users[upline].bonus = users[upline].bonus.add(amount);
					users[upline].totalBonus = users[upline].totalBonus.add(amount);
					emit RefBonus(upline, msg.sender, i, amount);
					upline = users[upline].referrer;
				} else break;
			}
		}

		if (user.deposits.length == 0) {
			user.checkpoint = block.timestamp;
			emit Newbie(msg.sender);
		}

		user.deposits.push(Deposit(plan, msg.value, block.timestamp));

		totalInvested = totalInvested.add(msg.value);

		emit NewDeposit(msg.sender, plan, msg.value);
	}

	function withdraw() public {
		User storage user = users[msg.sender];

		uint256 totalAmount = getUserDividends(msg.sender);
		uint256 referralBonus = getUserReferralBonus(msg.sender);

		if (referralBonus > 0) {
			user.bonus = 0;
			totalAmount = totalAmount.add(referralBonus);
		}

		require(totalAmount > 0, "User has no dividends");

		uint256 contractBalance = address(this).balance;
		if (contractBalance < totalAmount) {
			user.bonus = totalAmount.sub(contractBalance);
			totalAmount = contractBalance;
		} else {
            if(referralBonus > 0)
                totalRefBonus = totalRefBonus.add(referralBonus);
        }
        
        if(block.timestamp - user.firstwithdrawntime <= TIME_STEP) {
            require(user.daywithdrawnamount < WITHDRAW_MAX_PER_DAY_AMOUNT, "Exceed max withdrawn amount today");            

            if(user.daywithdrawnamount.add(totalAmount) > WITHDRAW_MAX_PER_DAY_AMOUNT) {
                uint256 additionalBonus = user.daywithdrawnamount.add(totalAmount).sub(WITHDRAW_MAX_PER_DAY_AMOUNT);
                user.bonus = user.bonus.add(additionalBonus);
                totalAmount = WITHDRAW_MAX_PER_DAY_AMOUNT.sub(user.daywithdrawnamount);
            }
            user.daywithdrawnamount = user.daywithdrawnamount.add(totalAmount);
        } else {
            if(totalAmount > WITHDRAW_MAX_PER_DAY_AMOUNT) {
                uint256 additionalBonus = totalAmount.sub(WITHDRAW_MAX_PER_DAY_AMOUNT);
                user.bonus = user.bonus.add(additionalBonus);
                totalAmount = WITHDRAW_MAX_PER_DAY_AMOUNT;                
            }
            user.firstwithdrawntime = block.timestamp;
            user.daywithdrawnamount = totalAmount;
        }

		user.checkpoint = block.timestamp;
		user.withdrawn = user.withdrawn.add(totalAmount);
		payable(msg.sender).transfer(totalAmount);
		emit Withdrawn(msg.sender, totalAmount);
	}

    function reinvest(uint8 plan) public {
        User storage user = users[msg.sender];

		uint256 totalAmount = getUserDividends(msg.sender);
		uint256 referralBonus = getUserReferralBonus(msg.sender);
		if (referralBonus > 0) {
			user.bonus = 0;
			totalAmount = totalAmount.add(referralBonus);
		}

		require(totalAmount > 0, "User has no dividends");

		uint256 contractBalance = address(this).balance;
		if (contractBalance < totalAmount) {
			user.bonus = totalAmount.sub(contractBalance);
			totalAmount = contractBalance;
		} else {
            if(referralBonus > 0)
                totalRefBonus = totalRefBonus = referralBonus;
        }

		user.withdrawn = user.withdrawn.add(totalAmount);

        require(totalAmount >= INVEST_MIN_AMOUNT);

		uint256 fee = totalAmount.mul(PROJECT_FEE).div(PERCENTS_DIVIDER);
        feeWallet.transfer(fee);
        uint256 devfee = totalAmount.mul(DEV_FEE).div(PERCENTS_DIVIDER);
        devWallet.transfer(devfee);

		emit FeePayed(msg.sender, fee.add(devfee));


		user.deposits.push(Deposit(plan, totalAmount, block.timestamp));
		totalInvested = totalInvested.add(totalAmount);
        user.checkpoint = block.timestamp;
		emit ReInvest(msg.sender, plan, totalAmount);
    }

    function canHarvest(address userAddress) public view returns(bool) {
        User storage user = users[userAddress];

        if(block.timestamp - user.firstwithdrawntime <= TIME_STEP){
            return user.daywithdrawnamount < WITHDRAW_MAX_PER_DAY_AMOUNT;
        } else {
            return true;
        }
    }

    function canReinvest(address userAddress) public view returns(bool) {
		uint256 totalAmount = getUserDividends(userAddress);
		uint256 referralBonus = getUserReferralBonus(userAddress);
		if (referralBonus > 0) 
			totalAmount = totalAmount.add(referralBonus);

		uint256 contractBalance = address(this).balance;
		if (contractBalance < totalAmount)
			totalAmount = contractBalance;

        return (totalAmount >= INVEST_MIN_AMOUNT);
    }

    function updateFeeWallet(address payable wallet) external {
        require(msg.sender == feeWallet, 'Limited Permission');
        emit FeeWalletUpdated(feeWallet, wallet);
        feeWallet = wallet;
    }

    function updateDevWallet(address payable dev) external {
        require(msg.sender == devWallet, 'Limited Permission');
        emit DevWalletUpdated(devWallet, dev);
        devWallet = dev;
    }

	function getContractBalance() public view returns (uint256) {
		return address(this).balance;
	}

	function getPlanInfo(uint8 plan) public view returns(uint256 time, uint256 percent) {
		time = plans[plan].time;
		percent = plans[plan].percent;
	}

	function getUserDividends(address userAddress) public view returns (uint256) {
		User storage user = users[userAddress];

		uint256 totalAmount;

		for (uint256 i = 0; i < user.deposits.length; i++) {
			uint256 finish = user.deposits[i].start.add(plans[user.deposits[i].plan].time.mul(1 days));
			if (user.checkpoint < finish) {
				uint256 share = user.deposits[i].amount.mul(plans[user.deposits[i].plan].percent).div(PERCENTS_DIVIDER);
				uint256 from = user.deposits[i].start > user.checkpoint ? user.deposits[i].start : user.checkpoint;
				uint256 to = finish < block.timestamp ? finish : block.timestamp;
				if (from < to) {
					totalAmount = totalAmount.add(share.mul(to.sub(from)).div(TIME_STEP));
				}
			}
		}
		return totalAmount;
	}

	function getUserTotalWithdrawn(address userAddress) public view returns (uint256) {
		return users[userAddress].withdrawn;
	}

	function getUserCheckpoint(address userAddress) public view returns(uint256) {
		return users[userAddress].checkpoint;
	}

	function getUserReferrer(address userAddress) public view returns(address) {
		return users[userAddress].referrer;
	}

	function getUserDownlineCount(address userAddress) public view returns(uint256[5] memory referrals) {
		return (users[userAddress].levels);
	}

	function getUserTotalReferrals(address userAddress) public view returns(uint256) {
		return users[userAddress].levels[0]+users[userAddress].levels[1]+users[userAddress].levels[2]+users[userAddress].levels[3]+users[userAddress].levels[4];
	}

	function getUserReferralBonus(address userAddress) public view returns(uint256) {
		return users[userAddress].bonus;
	}

	function getUserReferralTotalBonus(address userAddress) public view returns(uint256) {
		return users[userAddress].totalBonus;
	}

	function getUserReferralWithdrawn(address userAddress) public view returns(uint256) {
		return users[userAddress].totalBonus.sub(users[userAddress].bonus);
	}

	function getUserAvailable(address userAddress) public view returns(uint256) {
		return getUserReferralBonus(userAddress).add(getUserDividends(userAddress));
	}

	function getUserAmountOfDeposits(address userAddress) public view returns(uint256) {
		return users[userAddress].deposits.length;
	}

	function getUserTotalDeposits(address userAddress) public view returns(uint256 amount) {
		for (uint256 i = 0; i < users[userAddress].deposits.length; i++) {
			amount = amount.add(users[userAddress].deposits[i].amount);
		}
	}

	function getUserDepositInfo(address userAddress, uint256 index) public view returns(uint8 plan, uint256 percent, uint256 amount, uint256 start, uint256 finish) {
	    User storage user = users[userAddress];

		plan = user.deposits[index].plan;
		percent = plans[plan].percent;
		amount = user.deposits[index].amount;
		start = user.deposits[index].start;
		finish = user.deposits[index].start.add(plans[user.deposits[index].plan].time.mul(1 days));
	}

	function getSiteInfo() public view returns(uint256 _totalInvested, uint256 _totalBonus) {
		return(totalInvested, totalRefBonus);
	}

	function getUserInfo(address userAddress) public view returns(uint256 totalDeposit, uint256 totalWithdrawn, uint256 totalReferrals) {
		return(getUserTotalDeposits(userAddress), getUserTotalWithdrawn(userAddress), getUserTotalReferrals(userAddress));
	}

	function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
}