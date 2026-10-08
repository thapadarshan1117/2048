"""Mirror of lib/features/levels/domain/star_thresholds.dart."""


class StarThresholds:
    def __init__(self, two_star_score, three_star_score):
        self.two_star_score = two_star_score
        self.three_star_score = three_star_score

    def stars_for(self, score):
        if self.three_star_score > 0 and score >= self.three_star_score:
            return 3
        if self.two_star_score > 0 and score >= self.two_star_score:
            return 2
        return 1

    def progress_to_next_star(self, score, current_stars):
        if current_stars >= 3:
            return 1.0
        goal = self.three_star_score if current_stars >= 2 else self.two_star_score
        if goal <= 0:
            return 1.0
        return max(0.0, min(1.0, score / goal))

    def to_json(self):
        return {"twoStar": self.two_star_score, "threeStar": self.three_star_score}

    @staticmethod
    def from_json(data):
        return StarThresholds(int(data.get("twoStar", 0) or 0),
                              int(data.get("threeStar", 0) or 0))
