import math
for i in range(0, 90, 15):
    print(i, "slope: ", (int(math.sin(math.radians(i + 15)) * 1000) - int(math.sin(math.radians(i)) * 1000)) // 15)
    print(i, "b: ", int(math.sin(math.radians(i)) * 1000) - (((int(math.sin(math.radians(i + 15)) * 1000) - int(math.sin(math.radians(i)) * 1000)) // 15) * i))
print()
