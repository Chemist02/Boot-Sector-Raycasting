# Prints out encoded 16x16 map from some text file, where each wall is a '@' and '.' is a empty space.
# Input file must be 16x16.
# A map is encoded into 16 2 byte numbers, where each a wall is represented as a 1 in the number, and a 
# space is a 0. Leftmost walls are most significant in the numbers.

# Open map file.
fileName = input("Please specify map file to encode: ")
mapFile = open(fileName.strip())

#Loop through each line in file.
for line in mapFile:
    lineSum = 0
    for i in range(0, 16):
        # If wall is here, place a '1' at that location in our biinary number.
        if (line[i] == '@'):
            lineSum += 2 ** (15 - i)
    print(lineSum, end = ", ")
print()
