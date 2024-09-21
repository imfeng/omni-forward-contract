export function getSec(time: Date | string): number {
  if(typeof time === 'string') {
    return getSec(new Date(time));
  }
  return Math.floor(time.getTime() / 1000);
}

export function getRegisterMessage({
  userAddress,
  promoCode,
}: {
  userAddress: string
  promoCode: string
}) {
  return `CapVault: ${userAddress} set promoCode ${promoCode}`
}
