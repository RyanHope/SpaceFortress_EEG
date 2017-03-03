import math

def parseCell(cell):
    try:
        return int(cell)
    except ValueError:
        try:
            return float(cell)
        except ValueError:
            pass
    return cell

def parseRow(row):
    for j, x in enumerate(row):
        row[j] = parseCell(x)
    return row

def normDist(x, b=200, s=40):
    m = (b - s) / 2.
    return -1 + (x - s) / m

def distance(x1, y1, x2, y2):
    return math.hypot(x2 - x1, y2 - y1)

def signum(x):
    return (x > 0) - (x < 0)

def intersecting_segments(p0x, p0y, p1x, p1y, q0x, q0y, q1x, q1y):
    rx = p1x - p0x
    ry = p1y - p0y
    sx = q1x - q0x
    sy = q1y - q0y
    denom = (rx * sy) - (sx * ry)
    tnum = (sy * (q0x - p0x)) - (sx * (q0y - p0y))
    unum = (ry * (q0x - p0x)) - (rx * (q0y - p0y))
    if denom == 0 and unum == 0:
        if ((q0x <= p0x and p0x <= q1x) or (q0x >= p0x and p0x >= q1x)) and ((q0y <= p0y and p0y <= q1y) or (q0y >= p0y and p0y >= q1y)):
                return [p0x, p0y]
        elif ((q0x <= p1x and p1x <= q1x) or (q0x >= p1x and p1x >= q1x)) and ((q0y <= p1y and p1y <= q1y) or (q0y >= p1y and p1y >= q1y)):
            if ((p0x <= q0x and q0x <= p1x) and (p0y <= q0y and q0y <= p1y)) or ((p0x >= q0x and q0x >= p1x) and (p0y >= q0y and q0y >= p1y)):
                return [q0x, q0y]
            else:
                return [q1x, q1y]
        elif (signum(p0x - q0x) == signum(p1x - q0x)) and (signum(p0y - q0y) == signum(p1y - q0y)):
                return None
        else:
            if (abs(p0x - q0x) <= abs(p0x - q1x)) and (abs(p0y - q0y) <= abs(p0y - q1y)):
                return [q0x, q0y]
            else:
                return [q1x, q1y]
    elif denom == 0:
        return None
    else:
        tnumd = tnum / denom
        unumd = unum / denom
        if (0 <= tnumd and tnumd <= 1) and (0 <= unumd and unumd <= 1):
            return [p0x + (tnumd * rx), p0y + (tnumd * ry)]
        else:
            return None

def dist_to_hex(sx, sy, fx=355, fy=315, radius=None):
    angle = math.atan2(fy-sy, fx-sx)
    shipdist = distance(sx, sy, fx, fy)
    h1x = fx - radius
    h2x = fx - radius/2.
    h3x = fx + radius/2.
    h4x = fx + radius
    h1y = fy - radius * math.sqrt(3)/2.
    h2y = fy + radius * math.sqrt(3)/2.
    if 0 <= angle and angle <= math.pi/3.:
        segment = [h1x, fy, h2x, h1y]
    elif math.pi/3 <= angle and angle <= math.pi * (2/3.):
        segment = [h2x, h1y, h3x, h1y]
    elif math.pi * (2/3.) <= angle and angle <= math.pi:
        segment = [h3x, h1y, h4x, fy]
    elif 0 >= angle and angle >= math.pi/-3.:
        segment = [h1x, fy, h2x, h2y]
    elif math.pi/-3. >= angle and angle >= math.pi * (-2/3):
        segment = [h2x, h2y, h3x, h2y]
    else:
        segment = [h3x, h2y, h4x, fy]

def mydist(d, sx, sy):
    if d == None:
        return float("inf")
    else:
        return distance(sx, sy, d[0], d[1])

def travel_dist_to_hex(speed, sx, sy, vx, vy, fx=355, fy=315, radius=None):
    if speed == 0:
        return float("inf")
    vy = -vy
    h1x = fx - radius
    h2x = fx - radius/2.
    h3x = fx + radius/2.
    h4x = fx + radius
    h1y = fy - radius * math.sqrt(3)/2.
    h2y = fy + radius * math.sqrt(3)/2.

    segments = [
        [h1x, fy, h2x, h1y],
        [h2x, h1y, h3x, h1y],
        [h3x, h1y, h4x, fy],
        [h4x, fy, h3x, h2y],
        [h3x, h2y, h2x, h2y],
        [h2x, h2y, h1x, fy]
    ]

    return min([mydist(intersecting_segments(sx, sy, sx + 10000 * vx, sy + 10000 * vy, x[0], x[1], x[2], x[3]), sx, sy) for x in segments])

def travel_time_to_hex(speed, sx, sy, vx, vy, fx=355, fy=315, radius=None):
    if speed == 0:
        return float("inf")
    d = travel_dist_to_hex(speed, sx, sy, vx, vy, fx=fx, fy=fy, radius=radius)
    pps = speed * (1.0/.033)
    if d == float("inf"):
        return d
    else:
        return d / pps

def norm(x,y):
    return math.sqrt(x**2 + y**2)
