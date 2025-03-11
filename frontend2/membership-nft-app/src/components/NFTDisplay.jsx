import { useState, useEffect } from "react";
import { useReadContract } from "wagmi";
import contractABI from "../lib/MembershipNFT.json";

const NFTDisplay = ({ contractAddress, tokenId }) => {
  const [imageUrl, setImageUrl] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const { data: tokenURIData } = useReadContract({
    address: contractAddress,
    abi: contractABI.abi,
    functionName: "tokenURI",
    args: [tokenId],
    enabled: tokenId !== null && tokenId !== undefined,
  });

  useEffect(() => {
    if (tokenURIData) {
      try {
        const base64Json = tokenURIData.split(",")[1];
        const jsonString = atob(base64Json);
        const metadata = JSON.parse(jsonString);

        setImageUrl(metadata.image);
        setIsLoading(false);
      } catch (err) {
        console.error("Error parsing token URI:", err);
        setError("Failed to parse NFT data");
        setIsLoading(false);
      }
    }
  }, [tokenURIData]);

  if (isLoading) {
    return <div className="nft-loading">Loading NFT...</div>;
  }

  if (error) {
    return <div className="nft-error">{error}</div>;
  }

  if (!imageUrl) {
    return <div className="nft-unavailable">NFT image not available</div>;
  }

  return (
    <div className="nft-preview">
      <div className="nft-image-container">
        {/* Directly embed the SVG data URI */}
        <img
          src={imageUrl}
          alt="NFT"
          className="nft-image"
          onError={() => setError("Failed to load NFT image")}
        />
      </div>
    </div>
  );
};

export default NFTDisplay;
