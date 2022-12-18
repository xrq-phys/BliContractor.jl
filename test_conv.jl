include("conv.jl")

imgA = rand(3, 8, 8, 4);
kerB = rand(20, 3, 4, 4);
# outC = zeros(20, 5, 5, 4);
# conv!(outC, imgA, kerB)
outC = conv(imgA, kerB);

outC_r = zeros(20, 5, 5, 4);
for n=1:4, h=1:5, w=1:5, c=1:20
    outC_r[c, w, h, n] = sum(imgA[:, w:w+3, h:h+3, n] .* kerB[c, :, :, :]);
end

