import { ethers } from "hardhat";

/**
 * Converts a string to a bytes32 hex string representation.
 * @param text - The string to convert to bytes32.
 * @returns A bytes32 hex string padded to 32 bytes.
 * @example
 * ```typescript
 * const hash = toBytes32("Invoice #123");
 * // Returns: "0x496e766f696365202331323300000000000000000000000000000000000000"
 * ```
 */
export const toBytes32 = (text: string) => ethers.utils.formatBytes32String(text);

/**
 * Converts a bytes32 hex string back to a human-readable string.
 * @param bytes32 - The bytes32 hex string to parse.
 * @returns The decoded string with null bytes trimmed.
 * @example
 * ```typescript
 * const text = fromBytes32("0x496e766f696365202331323300000000000000000000000000000000000000");
 * // Returns: "Invoice #123"
 * ```
 */
export const fromBytes32 = (bytes32: string) => ethers.utils.parseBytes32String(bytes32);

/**
 * Converts a number or string to wei (the smallest unit of ether).
 * @param amount - The amount in ether to convert.
 * @returns A BigNumber representing the amount in wei.
 * @example
 * ```typescript
 * const weiAmount = toWei(1.5);
 * // Returns: BigNumber { value: "1500000000000000000" }
 * ```
 */
export const toWei = (amount: number | string) => ethers.utils.parseEther(amount.toString());

/**
 * Converts a BigNumber in wei to a human-readable ether string.
 * @param amount - The BigNumber amount in wei to convert.
 * @returns A string representing the amount in ether.
 * @example
 * ```typescript
 * const etherAmount = toEther(BigNumber.from("1500000000000000000"));
 * // Returns: "1.5"
 * ```
 */
export const toEther = (amount: any) => ethers.utils.formatEther(amount);

/**
 * Generates a formatted date label string from a Date object.
 * @param date - The Date object to format.
 * @returns A string in the format "M/D/YYYY" (e.g., "1/15/2024").
 * @example
 * ```typescript
 * const label = dateLabel(new Date("2024-01-15"));
 * // Returns: "1/15/2024"
 * ```
 */
export const dateLabel = (date: Date) =>
    `${date.getMonth() + 1}/${date.getDate()}/${date.getFullYear()}`;
