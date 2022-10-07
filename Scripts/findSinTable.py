import math
for i in range(0, 91, 15):
    print(i, "slope: ", (int(math.sin(math.radians(i + 15)) * 1024) - int(math.sin(math.radians(i)) * 1024)) // 15)
    print(i, "b: ", int(math.sin(math.radians(i)) * 1024) - (((int(math.sin(math.radians(i + 15)) * 1024) - int(math.sin(math.radians(i)) * 1024)) // 15) * i))
print()
