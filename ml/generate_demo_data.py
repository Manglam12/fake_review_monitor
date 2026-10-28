"""Creates a SYNTHETIC, DEMO-ONLY review CSV (no internet needed).

It is written from templates by this script. It is NOT real data, so any score
measured on it says nothing about real-world performance.
"""
import csv
import datetime as dt
import os
import random

R = random.Random(42)
PRODUCTS = [("P%02d" % i, n) for i, n in enumerate(
    ["headphones", "blender", "phone case", "backpack", "desk lamp", "water bottle",
     "keyboard", "yoga mat", "kettle", "charger", "sneakers", "watch"])]
ASPECTS = ["battery", "stitching", "sound quality", "packaging", "size", "delivery",
           "price", "handle", "colour", "material", "noise", "fit"]
G_OPEN = ["Bought this {p} two weeks ago.", "Used the {p} daily for a month.",
          "Got the {p} as a gift for my brother.", "Replaced my old {p} with this one.",
          "Ordered the {p} after reading a few comparisons."]
G_MID = ["The {a} is better than I expected.", "Only complaint is the {a}.",
         "The {a} feels a bit cheap but it does the job.", "I like the {a}, though the {b} could improve.",
         "The {a} took some getting used to.", "Surprisingly the {a} is solid, the {b} is average."]
G_END = ["Would buy again.", "Not perfect but fair for the price.", "Returned one, the replacement was fine.",
         "Three stars, it is okay.", "Works as described.", "Happy enough overall.", "Wish it came in more sizes."]
G_SHORT = ["Good product.", "Works fine.", "Arrived on time, ok.", "Not bad for the price.", "Decent.",
           "Broke after a week, disappointed."]
F_PROMO = ["BEST {p} EVER!!! Buy now, 100% guaranteed!!!", "Amazing {p}! Visit www.deals-{x}.com for free discount coupon!",
           "Must buy this {p}!!! Limited offer, use code SAVE{n}", "Cheap and perfect {p}, order now!!! WhatsApp +91 98{n}12345",
           "Best price {p} click the link, contact me at seller{n}@mail.com"]
F_STEALTH = ["Great product, highly recommend to everyone.", "Excellent quality, very satisfied with this purchase.",
             "Amazing {p}, love it, five stars.", "Perfect in every way, best purchase ever.",
             "Very good {p}, fast delivery, nice quality, recommend.", "Wonderful product, exceeded all my expectations."]


def genuine_text():
    if R.random() < 0.12:
        return R.choice(G_SHORT)
    p = R.choice(PRODUCTS)[1]
    a, b = R.sample(ASPECTS, 2)
    parts = [R.choice(G_OPEN).format(p=p), R.choice(G_MID).format(a=a, b=b)]
    if R.random() < .6:
        parts.append(R.choice(G_MID).format(a=R.choice(ASPECTS), b=b))
    parts.append(R.choice(G_END))
    return " ".join(parts)


def fake_text():
    p = R.choice(PRODUCTS)[1]
    if R.random() < 0.55:
        t = R.choice(F_STEALTH).format(p=p)
        return t if R.random() < .5 else t + " " + R.choice(F_STEALTH).format(p=p)
    return R.choice(F_PROMO).format(p=p, x=R.randint(1, 99), n=R.randint(10, 99))


def main(n=3000, out=None):
    out = out or os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "demo_reviews_DEMO_ONLY.csv")
    start = dt.datetime(2024, 1, 1)
    genuine_users = ["U%04d" % i for i in range(1, 1500)]
    fake_users = ["F%03d" % i for i in range(1, 60)]
    rows = []
    for i in range(n):
        fake = R.random() < 0.35
        if fake:
            text, user = fake_text(), R.choice(fake_users)
            rating = R.choice([5, 5, 5, 5, 4, 1]) if R.random() > .1 else None
            ts = start + dt.timedelta(days=sum(map(ord, user)) % 300, minutes=R.randint(0, 120))
        else:
            text, user = genuine_text(), R.choice(genuine_users)
            rating = R.choice([5, 4, 4, 3, 3, 2, 1, 5]) if R.random() > .1 else None
            ts = start + dt.timedelta(days=R.randint(0, 360), minutes=R.randint(0, 1440))
        label = "fake" if fake else "genuine"
        if R.random() < 0.02:  # a little label noise, like real life
            label = "genuine" if fake else "fake"
        rows.append([f"R{i:05d}", text, label, rating or "", user,
                     R.choice(PRODUCTS)[0], ts.strftime("%Y-%m-%d %H:%M:%S")])
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["review_id", "review_text", "label", "rating", "reviewer_id", "product_id", "timestamp"])
        w.writerows(rows)
    print("wrote", out, len(rows), "rows (SYNTHETIC / DEMO-ONLY)")


if __name__ == "__main__":
    main()
