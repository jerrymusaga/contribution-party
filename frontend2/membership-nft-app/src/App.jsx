import { useState, useEffect } from "react";
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  usePublicClient,
} from "wagmi";
import { parseEther, formatEther } from "viem";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import contractABI from "../src/lib/MembershipNFT.json";
import NFTDisplay from "./components/NFTDisplay";
import "./App.css";

const CONTRACT_ADDRESS = "0x9175fd8a8a07ba67fd5191c2b12524ee07188cfa";

function App() {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const [activeTab, setActiveTab] = useState("join");
  const [parties, setParties] = useState([]);
  const [partyCount, setPartyCount] = useState(0);
  const [newPartyName, setNewPartyName] = useState("");
  const [newPartyFee, setNewPartyFee] = useState("");
  const [isOwner, setIsOwner] = useState(false);
  const [loading, setLoading] = useState(false);
  const [refreshCounter, setRefreshCounter] = useState(0);

  const { writeContractAsync, data: writeData } = useWriteContract();

  const { data: ownerData } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: contractABI.abi,
    functionName: "owner",
  });

  const { data: partyCountData, refetch: refetchPartyCount } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: contractABI.abi,
    functionName: "partyCount",
  });

  const { isLoading: isWaitingForTransaction, isSuccess: transactionSuccess } =
    useWaitForTransactionReceipt({
      hash: writeData,
    });

  useEffect(() => {
    if (isConnected && ownerData && address) {
      setIsOwner(ownerData.toLowerCase() === address.toLowerCase());
    }
  }, [ownerData, address, isConnected]);

  useEffect(() => {
    if (partyCountData !== undefined) {
      setPartyCount(Number(partyCountData));
    }
  }, [partyCountData]);

  useEffect(() => {
    if (transactionSuccess) {
      setLoading(false);
      refetchPartyCount();

      setRefreshCounter((prev) => prev + 1);

      setNewPartyName("");
      setNewPartyFee("");
    }
  }, [transactionSuccess]);

  useEffect(() => {
    const fetchParties = async () => {
      if (partyCount > 0 && isConnected && publicClient) {
        setLoading(true);

        try {
          console.log("Fetching data for", partyCount, "parties");

          const calls = [];

          for (let i = 0; i < partyCount; i++) {
            calls.push({
              address: CONTRACT_ADDRESS,
              abi: contractABI.abi,
              functionName: "parties",
              args: [i],
            });
          }

          const partyResults = await publicClient.multicall({
            contracts: calls,
          });

          console.log("Party raw results:", partyResults);

          const memberships = Array(partyCount)
            .fill()
            .map(() => ({
              isMember: false,
              tokenId: null,
            }));

          if (isConnected && address) {
            const membershipCalls = [];

            for (let i = 0; i < partyCount; i++) {
              membershipCalls.push({
                address: CONTRACT_ADDRESS,
                abi: contractABI.abi,
                functionName: "isMember",
                args: [i, address],
              });
            }

            const membershipResults = await publicClient.multicall({
              contracts: membershipCalls,
            });

            console.log("Membership results:", membershipResults);

            const tokenCalls = [];
            const tokenPartyIndices = [];

            for (let i = 0; i < partyCount; i++) {
              if (
                membershipResults[i].status === "success" &&
                membershipResults[i].result === true
              ) {
                tokenCalls.push({
                  address: CONTRACT_ADDRESS,
                  abi: contractABI.abi,
                  functionName: "memberTokens",
                  args: [address, i],
                });
                tokenPartyIndices.push(i);
                memberships[i].isMember = true;
              }
            }

            if (tokenCalls.length > 0) {
              const tokenResults = await publicClient.multicall({
                contracts: tokenCalls,
              });

              console.log("Token results:", tokenResults);

              for (let i = 0; i < tokenResults.length; i++) {
                if (tokenResults[i].status === "success") {
                  const partyIndex = tokenPartyIndices[i];
                  memberships[partyIndex].tokenId = tokenResults[i].result;
                }
              }
            }
          }

          const processedParties = [];
          for (let i = 0; i < partyCount; i++) {
            if (partyResults[i].status === "success") {
              const partyData = partyResults[i].result;

              const party = {
                id: i,
                name: partyData[0],
                joinFee: partyData[1],
                memberCount: Number(partyData[2]),
                totalContributions: partyData[3],
                isMember: memberships[i].isMember,
                tokenId: memberships[i].tokenId,
              };

              processedParties.push(party);
            } else {
              console.error(
                `Error fetching party ${i}:`,
                partyResults[i].error
              );
            }
          }

          console.log("Processed parties:", processedParties);
          setParties(processedParties);
        } catch (error) {
          console.error("Error fetching parties:", error);
        } finally {
          setLoading(false);
        }
      }
    };

    fetchParties();
  }, [partyCount, isConnected, address, publicClient, refreshCounter]);

  const handleCreateParty = async () => {
    if (!newPartyName || !newPartyFee) {
      alert("Please enter both name and fee");
      return;
    }

    try {
      setLoading(true);
      const feeInWei = parseEther(newPartyFee);
      await writeContractAsync({
        address: CONTRACT_ADDRESS,
        abi: contractABI.abi,
        functionName: "createParty",
        args: [newPartyName, feeInWei],
      });
    } catch (error) {
      console.error("Error creating party:", error);
      alert("Error creating party. Please check console for details.");
      setLoading(false);
    }
  };

  const handleJoinParty = async (partyId, fee) => {
    try {
      setLoading(true);
      await writeContractAsync({
        address: CONTRACT_ADDRESS,
        abi: contractABI.abi,
        functionName: "payContributionToJoinParty",
        args: [partyId],
        value: fee,
      });
    } catch (error) {
      console.error("Error joining party:", error);
      alert("Error joining party. Please check console for details.");
      setLoading(false);
    }
  };

  const handleWithdraw = async (partyId) => {
    try {
      setLoading(true);
      await writeContractAsync({
        address: CONTRACT_ADDRESS,
        abi: contractABI.abi,
        functionName: "withdrawContributions",
        args: [partyId, address],
      });
    } catch (error) {
      console.error("Error withdrawing contributions:", error);
      alert(
        "Error withdrawing contributions. Please check console for details."
      );
      setLoading(false);
    }
  };

  // Render functions
  const renderJoinTab = () => (
    <div className="tab-content">
      <h2>Join a Party</h2>
      {loading ? (
        <p>Loading parties...</p>
      ) : parties.length > 0 ? (
        <div className="party-list">
          {parties.map((party) => (
            <div key={party.id} className="party-card">
              <h3>{party.name}</h3>
              <p>Join Fee: {formatEther(party.joinFee)} ETH</p>
              <p>Members: {party.memberCount}</p>
              <p>Status: {party.isMember ? "Member" : "Not a Member"}</p>
              {!party.isMember && (
                <button
                  onClick={() => handleJoinParty(party.id, party.joinFee)}
                  disabled={loading || isWaitingForTransaction}
                >
                  {loading || isWaitingForTransaction
                    ? "Processing..."
                    : `Join for ${formatEther(party.joinFee)} ETH`}
                </button>
              )}
            </div>
          ))}
        </div>
      ) : (
        <p>No parties available to join</p>
      )}
    </div>
  );

  const renderMyMembershipsTab = () => (
    <div className="tab-content">
      <h2>My Memberships</h2>
      {loading ? (
        <p>Loading memberships...</p>
      ) : parties.filter((party) => party.isMember).length > 0 ? (
        <div className="party-list">
          {parties
            .filter((party) => party.isMember)
            .map((party) => (
              <div key={party.id} className="party-card membership-card">
                <h3>{party.name}</h3>
                <p>
                  Token ID:{" "}
                  {party.tokenId !== null && party.tokenId !== undefined
                    ? Number(party.tokenId)
                    : "Not available"}
                </p>

                {party.tokenId !== null && party.tokenId !== undefined ? (
                  <NFTDisplay
                    contractAddress={CONTRACT_ADDRESS}
                    tokenId={party.tokenId}
                  />
                ) : (
                  <div className="nft-preview">
                    <div className="mock-nft">
                      <div className="nft-title">Membership NFT</div>
                      <div className="nft-party">{party.name}</div>
                    </div>
                  </div>
                )}

                <button
                  onClick={() => {
                    if (party.tokenId !== null && party.tokenId !== undefined) {
                      window.open(
                        `https://testnets.opensea.io/assets/sepolia/${CONTRACT_ADDRESS}/${party.tokenId}`
                      );
                    } else {
                      alert("Token ID not available");
                    }
                  }}
                  disabled={
                    party.tokenId === null || party.tokenId === undefined
                  }
                >
                  View on OpenSea
                </button>
              </div>
            ))}
        </div>
      ) : (
        <p>You are not a member of any parties</p>
      )}
    </div>
  );

  const renderAdminTab = () => (
    <div className="tab-content">
      <h2>Admin Panel</h2>

      <div className="admin-section">
        <h3>Create New Party</h3>
        <div className="form-group">
          <label>Name:</label>
          <input
            type="text"
            value={newPartyName}
            onChange={(e) => setNewPartyName(e.target.value)}
            placeholder="Party Name"
          />
        </div>
        <div className="form-group">
          <label>Join Fee (ETH):</label>
          <input
            type="text"
            value={newPartyFee}
            onChange={(e) => setNewPartyFee(e.target.value)}
            placeholder="0.01"
          />
        </div>
        <button
          onClick={handleCreateParty}
          disabled={
            loading || isWaitingForTransaction || !newPartyName || !newPartyFee
          }
        >
          {loading || isWaitingForTransaction ? "Creating..." : "Create Party"}
        </button>
      </div>

      <div className="admin-section">
        <h3>Manage Parties</h3>
        {loading ? (
          <p>Loading parties...</p>
        ) : parties.length > 0 ? (
          <div className="party-list">
            {parties.map((party) => (
              <div key={party.id} className="party-card">
                <h3>{party.name}</h3>
                <p>Members: {party.memberCount}</p>
                <p>
                  Total Contributions: {formatEther(party.totalContributions)}{" "}
                  ETH
                </p>
                <button
                  onClick={() => handleWithdraw(party.id)}
                  disabled={
                    loading ||
                    isWaitingForTransaction ||
                    Number(party.totalContributions) === 0
                  }
                >
                  {loading || isWaitingForTransaction
                    ? "Processing..."
                    : `Withdraw ${formatEther(party.totalContributions)} ETH`}
                </button>
              </div>
            ))}
          </div>
        ) : (
          <p>No parties created yet</p>
        )}
      </div>
    </div>
  );

  return (
    <div className="app-container">
      <header>
        <h1>Membership NFT Platform</h1>
        <ConnectButton />
      </header>

      {isConnected ? (
        <main>
          <nav className="tabs">
            <button
              className={activeTab === "join" ? "active" : ""}
              onClick={() => setActiveTab("join")}
            >
              Join Party
            </button>
            <button
              className={activeTab === "memberships" ? "active" : ""}
              onClick={() => setActiveTab("memberships")}
            >
              My Memberships
            </button>
            {isOwner && (
              <button
                className={activeTab === "admin" ? "active" : ""}
                onClick={() => setActiveTab("admin")}
              >
                Admin
              </button>
            )}
          </nav>

          {activeTab === "join" && renderJoinTab()}
          {activeTab === "memberships" && renderMyMembershipsTab()}
          {activeTab === "admin" && isOwner && renderAdminTab()}
        </main>
      ) : (
        <div className="connect-prompt">
          <p>Please connect your wallet to use the application</p>
        </div>
      )}
    </div>
  );
}

export default App;
