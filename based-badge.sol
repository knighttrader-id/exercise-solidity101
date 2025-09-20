// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title BasedBadge
 * @dev ERC1155 multi-token for badges, certificates, and achievements
 * Token types:
 * - Non-transferable certificates
 * - Fungible event badges
 * - Limited achievement medals
 * - Workshop session tokens
 */
contract BasedBadge is ERC1155, AccessControl, Pausable, ERC1155Supply {
    // --- Role definitions ---
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // --- Token ID ranges for organization ---
    uint256 public constant CERTIFICATE_BASE = 1000;
    uint256 public constant EVENT_BADGE_BASE = 2000;
    uint256 public constant ACHIEVEMENT_BASE = 3000;
    uint256 public constant WORKSHOP_BASE = 4000;

    // --- Token metadata structure ---
    struct TokenInfo {
        string name;
        string category;
        uint256 maxSupply;
        bool isTransferable;
        uint256 validUntil; // 0 = no expiry
        address issuer;
    }

    // --- Mappings ---
    mapping(uint256 => TokenInfo) public tokenInfo;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) public holderTokens;
    mapping(uint256 => mapping(address => uint256)) public earnedAt;

    // --- Counters for unique IDs ---
    uint256 private _certificateCounter;
    uint256 private _eventCounter;
    uint256 private _achievementCounter;
    uint256 private _workshopCounter;

    // --- Events ---
    event TokenTypeCreated(uint256 indexed tokenId, string name, string category);
    event BadgeIssued(uint256 indexed tokenId, address to, uint256 amount);
    event BatchBadgesIssued(uint256 indexed tokenId, uint256 count, uint256 amount);
    event AchievementGranted(uint256 indexed tokenId, address student, string achievement);

    constructor() ERC1155("") {
        // --- Setup roles ---
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
      * @dev Create new badge or certificate type
      */
    function createBadgeType(
        string memory name,
        string memory category,
        uint256 maxSupply,
        bool transferable,
        string memory tokenURI
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId;
        // Input validation
        require(
            bytes(name).length > 0 &&
            bytes(tokenURI).length > 0 &&
            bytes(category).length > 0,
            "Invalid input"
        );

        // Pick category range based on category string
        if (keccak256(bytes(category)) == keccak256(bytes("certificate"))) {
            tokenId = CERTIFICATE_BASE + _certificateCounter++;
        } else if (keccak256(bytes(category)) == keccak256(bytes("event"))) {
            tokenId = EVENT_BADGE_BASE + _eventCounter++;
        } else if (keccak256(bytes(category)) == keccak256(bytes("achievement"))) {
            tokenId = ACHIEVEMENT_BASE + _achievementCounter++;
        } else if (keccak256(bytes(category)) == keccak256(bytes("workshop"))) {
            tokenId = WORKSHOP_BASE + _workshopCounter++;
        } else {
            revert("BasedBadge: Invalid category");
        }

        // Store TokenInfo
        tokenInfo[tokenId] = TokenInfo({
            name: name,
            category: category,
            maxSupply: maxSupply,
            isTransferable: transferable,
            validUntil: 0, // No expiry by default
            issuer: msg.sender
        });

        // Save URI
        _tokenURIs[tokenId] = tokenURI;

        // Emit TokenTypeCreated
        emit TokenTypeCreated(tokenId, name, category);

        // Return tokenId
        return tokenId;
    }

    /**
      * @dev Issue single badge/certificate to user
      */
    function issueBadge(address to, uint256 tokenId) public onlyRole(MINTER_ROLE) {
        // Verify tokenId exists
        require(tokenInfo[tokenId].issuer != address(0), "BasedBadge: Token type does not exist");

        // Check supply limit
        uint256 currentSupply = totalSupply(tokenId);
        require(currentSupply < tokenInfo[tokenId].maxSupply || tokenInfo[tokenId].maxSupply == 0, "BasedBadge: Max supply reached");

        // Mint token to user
        _mint(to, tokenId, 1, "");

        // Record timestamp
        earnedAt[tokenId][to] = block.timestamp;

        // Save to holderTokens
        holderTokens[to].push(tokenId);

        // Emit BadgeIssued
        emit BadgeIssued(tokenId, to, 1);
    }

    /**
      * @dev Batch mint badges for events
      */
    function batchIssueBadges(address[] calldata recipients, uint256 tokenId, uint256 amount)
        public onlyRole(MINTER_ROLE)
    {
        require(recipients.length <= 100, "BasedBadge: Batch too large"); // Gas limit protection

        // Verify tokenId exists
        require(tokenInfo[tokenId].issuer != address(0), "BasedBadge: Token type does not exist");

        // Check supply limit for total batch
        uint256 currentSupply = totalSupply(tokenId);
        uint256 totalMintAmount = amount * recipients.length;
        require(currentSupply + totalMintAmount <= tokenInfo[tokenId].maxSupply || tokenInfo[tokenId].maxSupply == 0, "BasedBadge: Max supply would be exceeded");

        // Loop through recipients
        for (uint256 i = 0; i < recipients.length; ++i) {
            // Mint amount to each
            _mint(recipients[i], tokenId, amount, "");

            // Record timestamp
            earnedAt[tokenId][recipients[i]] = block.timestamp;

            // Save to holderTokens
            holderTokens[recipients[i]].push(tokenId);
        }

        // Emit BatchBadgesIssued
        emit BatchBadgesIssued(tokenId, recipients.length, amount);
    }

    /**
      * @dev Grant special achievement to student
      */
    function grantAchievement(address student, string memory achievementName, uint256 rarity, uint256 validUntil)
        public onlyRole(MINTER_ROLE) returns (uint256)
    {
        // Generate achievement tokenId
        uint256 tokenId = ACHIEVEMENT_BASE + _achievementCounter++;

        // Store TokenInfo (rarity affects maxSupply)
        // Higher rarity = lower maxSupply
        uint256 maxSupply = rarity == 1 ? 100 : rarity == 2 ? 50 : rarity == 3 ? 25 : 10;

        tokenInfo[tokenId] = TokenInfo({
            name: achievementName,
            category: "achievement",
            maxSupply: maxSupply,
            isTransferable: false, // Achievements are non-transferable
            validUntil: validUntil, // Use provided expiry
            issuer: msg.sender
        });

        // Set URI for achievement metadata
        _tokenURIs[tokenId] = string.concat("https://api.example.com/achievement/", Strings.toString(tokenId));


        // Mint 1 achievement NFT
        _mint(student, tokenId, 1, "");

        // Record timestamp
        earnedAt[tokenId][student] = block.timestamp;

        // Save to holderTokens
        holderTokens[student].push(tokenId);

        // Emit AchievementGranted
        emit AchievementGranted(tokenId, student, achievementName);

        // Return tokenId
        return tokenId;
    }

    /**
      * @dev Create workshop series with multiple sessions
      */
    function createWorkshop(string memory seriesName, uint256 totalSessions)
        public onlyRole(MINTER_ROLE) returns (uint256[] memory)
    {
        uint256[] memory sessionIds = new uint256[](totalSessions);

        // Loop for totalSessions
        for (uint256 i = 0; i < totalSessions; ++i) {
            // Generate tokenIds under WORKSHOP_BASE
            uint256 tokenId = WORKSHOP_BASE + _workshopCounter++;

            // Store TokenInfo
            tokenInfo[tokenId] = TokenInfo({
                name: string(abi.encodePacked(seriesName, " - Session ", Strings.toString(i + 1))),
                category: "workshop",
                maxSupply: 100, // Default max supply for workshop sessions
                isTransferable: false, // Workshop tokens are non-transferable
                validUntil: 0, // No expiry
                issuer: msg.sender
            });

            // Set URI for workshop session metadata
            _tokenURIs[tokenId] = string.concat("https://api.example.com/workshop/", Strings.toString(tokenId));

            // Store session ID
            sessionIds[i] = tokenId;

            // Emit TokenTypeCreated
            emit TokenTypeCreated(tokenId, tokenInfo[tokenId].name, tokenInfo[tokenId].category);
        }

        // Return array of session IDs
        return sessionIds;
    }

    /**
      * @dev Set metadata URI
      */
    function setURI(uint256 tokenId, string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        // Store URI in mapping
        _tokenURIs[tokenId] = newuri;
    }

    /**
      * @dev Get all tokens owned by a student
      */
    function getTokensByHolder(address holder) public view returns (uint256[] memory) {
        return holderTokens[holder];
    }

    /**
      * @dev Verify badge validity
      */
    function verifyBadge(address holder, uint256 tokenId)
        public view returns (bool valid, uint256 earnedTimestamp)
    {
        // Check if token exists
        require(tokenInfo[tokenId].issuer != address(0), "BasedBadge: Token does not exist");

        // Check balance > 0
        bool hasBalance = balanceOf(holder, tokenId) > 0;
        if (!hasBalance) {
            return (false, 0);
        }

        // Get earned timestamp
        earnedTimestamp = earnedAt[tokenId][holder];

        // Check expiry (if any)
        if (tokenInfo[tokenId].validUntil != 0) {
            valid = block.timestamp <= tokenInfo[tokenId].validUntil;
        } else {
            valid = true; // No expiry set
        }

        // Return status + timestamp
        return (valid, earnedTimestamp);
    }

    /**
     * @dev Pause / unpause transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
      * @dev Restrict transferability and check pause
      */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        // Restrict non-transferable tokens
        for (uint i = 0; i < ids.length; ++i) {
            if (from != address(0) && to != address(0)) {
                require(
                    tokenInfo[ids[i]].isTransferable,
                    "BasedBadge: This token is non-transferable"
                );
            }
        }
        super._update(from, to, ids, values);
    }

    /**
      * @dev Return custom URI
      */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }

    /**
     * @dev Check interface support
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}