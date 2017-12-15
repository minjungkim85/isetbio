function [cImg, cPixels] = hcimageRotateClip(hc, clipPrctile, nRot)
% Clip and rotate hypercube data. Used for visualization with specularities
%
% Syntax:
%    [cImg, cPixels] = hcimageRotateClip(hc, clipPrctile, nRot)
%
% Description:
%    Clip and rotate the hypercube data. This is used for visualization
%    with specularities.
%
% Inputs:
%    hc          - Hypercube image data, uint16 usually
%    clipPrctile - (Optional) 0-100, percentile for clipping. Default 99.9.
%    nRot        - (Optional) The number of counter-clockwise rotation
%                  steps, usually 0 or 1. Default is 1.
%
% Outputs:
%    cImg        - The hypercube image data
%    cPixels     - The hypercube pixel data
%
% Notes:
%    * [Note: JNM - Example does not work. the hypercube image (img) has
%      not been defined.]

% History:
%    xx/xx/12       (c) Imageval, 2012
%    12/06/17  jnm  Formatting

% Examples:
%{
    img = macbethChartCreate;
    clipPrctile = 99.9;
    nRot = 1;
    [hc, cPixels] = hcimageRotateClip(img.data, clipPrctile, nRot);
    vcNewGraphWin;
    imagesc(cPixels)
%}

if notDefined('hc'); error('hyper cube image required'); end
if notDefined('clipPrctile'), clipPrctile = 99.9; end
if notDefined('nRot'), nRot = 1; end

[r, c, w] = size(hc);
if abs(nRot) == 1
    % We rotate the image before clipping, so r, c inverted
    cPixels = zeros(c, r);
    cImg = zeros(c, r, w);
else
    cPixels = zeros(c, r);
    if isa(img, 'uint16')
        cImg = zeros(r, c, w, 'uint16');
    else
        cImg = zeros(c, r, w, 'double');
    end
end

% For each waveband, rotate as requested and clip
h = waitbar(0, 'Rotating and clipping');
for ii = 1:w
    waitbar(ii / w, h)
    if nRot ~= 0, tmp = rot90(double(hc(:, :, ii)), nRot); end
    if clipPrctile < 100
        mx = iePrctile(tmp(:), clipPrctile);
        cPixels =  cPixels + (tmp > mx);
        tmp(tmp > mx) = 0;
    end
    cImg(:, :, ii)  = tmp;
end
close(h)

% subplot(1, 2, 1), imagesc(tmp);
% axis image;
% colormap(gray);
% subplot(1, 2, 2), imagesc(foo);
% axis image;
% colormap(gray);
end