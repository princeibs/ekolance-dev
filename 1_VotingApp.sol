// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


interface IVotingContract{

//only one address should be able to add candidates
    function addCandidate(bytes32 candidateName) external returns(bool);

    
    function voteCandidate(uint candidateId) external returns(bool);

    //getWinner returns the name of the winner
    function getWinner() external returns(bytes32);
}


/** 
 * @title Ballot
 * @dev Implements voting process along with vote delegation
 */
contract Ballot is IVotingContract{
   
    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to
        uint vote;   // index of the voted proposal
    }

    struct Candidate {
        // If you can limit the length to a certain number of bytes, 
        // always use one of bytes1 to bytes32 because they are much cheaper
        bytes32 name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    uint256 public startTime;

    uint256 public duration = 180;

    address public chairperson;    

    mapping(address => Voter) public voters;

    Candidate[] public candidates;

    /** 
     * @dev Create a new ballot.
     */
    constructor() {
        startTime = block.timestamp;
        chairperson = msg.sender;
        voters[chairperson].weight = 1;
    }


    function addCandidate(bytes32 _candidateName) public returns(bool successfullyAdded) {
        require(block.timestamp < startTime + duration, "You can't add a new candidate at this time");
        require(msg.sender == chairperson, "Only the chairperson can add candidate");
        candidates.push(Candidate(_candidateName, 0));
        successfullyAdded = true;
    }
    
    /** 
     * @dev Give 'voter' the right to vote on this ballot. May only be called by 'chairperson'.
     * @param voter address of voter
     */
    function giveRightToVote(address voter) public {
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote."
        );
        require(
            !voters[voter].voted,
            "The voter already voted."
        );
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    /**
     * @dev Delegate your vote to the voter 'to'.
     * @param to address to which vote is delegated
     */
    function delegate(address to) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "You already voted.");
        require(to != msg.sender, "Self-delegation is disallowed.");

        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.voted) {
            // If the delegate already voted,
            // directly add to the number of votes
            candidates[delegate_.vote].voteCount += sender.weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /**
     * @dev Give your vote (including votes delegated to you) to proposal 'proposals[proposal].name'.
     * @param candidateId index of proposal in the proposals array
     */
    function voteCandidate(uint candidateId) public returns(bool successfullyVoted) {
        Voter storage sender = voters[msg.sender];
        require(block.timestamp > startTime + duration, "It's not yet time to vote");
        require(block.timestamp < startTime + (duration * 2), "Time to vote has passed");
        require(sender.weight != 0, "Has no right to vote");
        require(!sender.voted, "Already voted.");
        sender.voted = true;
        sender.vote = candidateId;

        // If 'proposal' is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        candidates[candidateId].voteCount += sender.weight;

        successfullyVoted = true;
    }

    /** 
     * @dev Computes the winning proposal taking all previous votes into account.
     * @return winningCandidate_ index of winning proposal in the proposals array
     */
    function winningCandidate() public view
            returns (uint winningCandidate_)
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < candidates.length; p++) {
            if (candidates[p].voteCount > winningVoteCount) {
                winningVoteCount = candidates[p].voteCount;
                winningCandidate_ = p;
            }
        }
    }

    /** 
     * @dev Calls winningProposal() function to get the index of the winner contained in the proposals array and then
     * @return winnerName_ the name of the winner
     */
    function getWinner() public view
            returns (bytes32 winnerName_)
    {
        require(block.timestamp > startTime + (duration * 2), "Result is not yet ready");
        winnerName_ = candidates[winningCandidate()].name;
    }
}
