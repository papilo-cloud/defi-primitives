import {ethers} from "ethers";

async function permitAndSwap() {
    // Setup
    const signer = await provider.getSignature();
    const token = new ethers.Contract(tokenAddress, tokenABI, signer);
    const owner = await signer.getAddress();

    // 1. Prepare permit data
    const spender = UNISWAP_ROUTER_ADDRESS;
    const value = ethers.parseEther("100");
    const nonce = await token.nonces(owner);
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour

    // 2. Create EIP-712 domain
    const domain = {
        name: await token.name(),
        version: '1',
        chainId: (await provider.getNetwork()).chainId,
        verifyingContract: await token.getAddress()
    }

    // 3. Define types (matches PERMIT_TYPEHASH)
    const types = {
        Permit: [
            {name: 'owner', type: 'address'},
            {name: 'spender', type: 'address'},
            {name: 'value', type: 'uint256'},
            {name: 'nonce', type: 'uint256'},
            {name: 'deadline', type: 'uint256'},
        ]
    };

    // 4. Create value object
    const permitData = {
        owner,
        spender,
        value,
        nonce,
        deadline
    }

    // 5. User signs (FREE, no gas!)
    const signature = await signer.signTypedData(domain, types, permitData)
    const {v, r, s} = ethers.Signature.from(signature);

    console.log('Signature created:', {v, r, s});
    console.log('User paid 0 gas!');

    // 6. Submit permit + swap in ONE transaction
    const router = new ethers.Contract(UNISWAP_ROUTER_ADDRESS, routerABI, signer);
    const tx = await router.swapWithPermit(
        // permit params:
        owner,
        spender,
        value,
        deadline,
        v, r, s,

        // Swap params:
        swapPath,
        minAmountOut,
        // ...
    );

    await tx.wait()
    console.log('Done! Only 1 transaction needed')
}