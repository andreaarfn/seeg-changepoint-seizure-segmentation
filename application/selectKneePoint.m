function selectedCount = selectKneePoint(changeCounts, residuals)

x = double(changeCounts(:));
y = double(residuals(:));

valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);

if isempty(x)
    error("No valid residual values were produced.");
end

if numel(x) <= 2
    selectedCount = round(x(end));
    return
end

xNorm = (x - x(1)) / max(x(end) - x(1), eps);
yNorm = (y - min(y)) / max(max(y) - min(y), eps);

lineY = yNorm(1) + (yNorm(end) - yNorm(1)) .* xNorm;
distance = abs(yNorm - lineY);

[~, idx] = max(distance);
selectedCount = round(x(idx));

end
