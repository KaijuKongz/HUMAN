pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintable20 is IERC20 {
	function mint(address _user, uint256 _amount) external;
}

interface INFT is IERC721 {
}

contract YieldHub is Ownable {
	using SafeMath for uint256;

	struct YieldToken {
		uint8 issuanceType; // mint/transfer
		uint256 tokenId;
		uint256 start;
		uint256 end;
		uint256 rate;
	}

	struct UserData {
		uint256 rewards;
		uint256 lastUpdate;
	}

	INFT public nft;

	mapping(address => YieldToken) public yieldTokens;
	mapping(uint256 => address) public indexToAddress;
	uint256 public yieldTokenCount;

	// user => token => user data
	mapping(address => mapping(address => UserData)) public userData;

	///////////
	// admin //
	///////////
	function updateNFT(address _newNFT) external onlyOwner {
		nft = INFT(_newNFT);
	}

	function addNewToken(
		address _token,
		uint256 _start,
		uint256 _end,
		uint256 _tokenId,
		uint256 _rate,
		uint256 _issuanceType // mint/transfer
	) external onlyOwner {
		require(_start > 0);
		require(_token != address(0));
		require(_issuanceType <= 1);
		require(_start > yieldTokens[_token].end);
		require(nft != INFT(address(0)));

		indexToAddress[yieldTokenCount++] = _token;
		yieldTokens[_token] = YieldToken({
			issuanceType: uint8(_issuanceType),
			tokenId: _tokenId,
			start: _start,
			end: _end,
			rate: _rate
		});
	}

	function removeToken(address _token) external onlyOwner {
		require(block.timestamp >= yieldTokens[_token].end, "Can't remove token");
		uint256 count = yieldTokenCount;

		for (uint256 i = 0; i < count; i++) {
			if (_token == indexToAddress[i]) {
				if (i + 1 != count) {
					indexToAddress[i] = indexToAddress[count - 1];
				}
				yieldTokenCount--;
				delete indexToAddress[count - 1];
			}
		}
	}

	///////////////////////
	// User interactions //
	///////////////////////
	function getTokenReward(address _token) public {
		uint256 balOf = nft.balanceOf(msg.sender);

		updateUserToken(msg.sender, _token, balOf);
		_getReward(_token, msg.sender);
	}

	function getTotalClaimable(address _user, address _token) external view returns(uint256) {
		UserData memory data = userData[_user][_token];
		YieldToken memory yieldToken = yieldTokens[_token];
		uint256 time = min(block.timestamp, yieldToken.end);
		uint256 bal;
		uint256 delta = time.sub(max(data.lastUpdate, yieldToken.start));

		bal = nft.balanceOf(_user);
		uint256 pending = bal.mul(yieldToken.rate.mul(delta)).div(86400);
		return data.rewards + pending;
	}

	// called on transfers
	function updateReward(address _from, address _to) external {
		require(msg.sender == address(nft), "!nft caller");
		uint256 tokensFarmed = yieldTokenCount;
		if (_from != address(0))
			updateUser(_from, tokensFarmed);
		if (_to != address(0))
			updateUser(_to, tokensFarmed);
	}

	////////////
	// helper //
	////////////
	function min(uint256 a, uint256 b) internal pure returns (uint256) {
		return a < b ? a : b;
	}

	function max(uint256 a, uint256 b) internal pure returns (uint256) {
		return a > b ? a : b;
	}

	function updateUser(address _user, uint256 _tokensFarmed) internal {
		uint256 balOf = nft.balanceOf(_user);

		for (uint256 i = 0; i < _tokensFarmed; i++)
			updateUserToken(_user, indexToAddress[i], balOf);
	}

	function updateUserToken(address _user, address _token, uint256 _balOf) internal {
		YieldToken memory yieldToken = yieldTokens[_token];
		UserData storage _userData = userData[_user][_token];

		if (block.timestamp > yieldToken.start) {
			uint256 trueLastUpdate = _userData.lastUpdate;
			uint256 userLastUpdate = trueLastUpdate;
			uint256 time = min(yieldToken.end, block.timestamp);
			uint256 delta;
			userLastUpdate = max(userLastUpdate, yieldToken.start);
			delta = time.sub(userLastUpdate);
			if (userLastUpdate > 0 && delta > 0) {
				_userData.rewards += _balOf.mul(yieldToken.rate).mul(delta).div(86400);
			}
			if (trueLastUpdate < time)
				_userData.lastUpdate = time;
		}
	}

	function _getReward(address _token, address _user) internal {
		YieldToken memory yieldToken = yieldTokens[_token];
		require(yieldToken.start > 0);
		UserData storage _userData = userData[_user][_token];
		uint256 amount = _userData.rewards;

		if (amount == 0)
			return;
		_userData.rewards = 0;
		
		if (yieldToken.issuanceType == 0) // mint
			IMintable20(_token).mint(_user, amount);
		else
			IERC20(_token).transfer(_user, amount);
	}
}
