function data = quadrantData(allQuadrantData, quadrantsToAverage, quadrantsComputed, subjectsToAverage, subjectsComputed)
 
    data = [];
    retinalPoolingRadiiNum = size(allQuadrantData,1);
    quadrantsNum = numel(quadrantsToAverage);
    subjectsNum = numel(subjectsToAverage);
    for k = 1:quadrantsNum
        [includeThisQuadrant,k_idx] = ismember(quadrantsToAverage{k}, quadrantsComputed);
        if (includeThisQuadrant)
            for s = 1:subjectsNum
                 [includeThisSubject,s_idx] = ismember(subjectsToAverage(s), subjectsComputed);
                 if (includeThisSubject)
                    data = cat(2,data,squeeze(allQuadrantData(1:retinalPoolingRadiiNum, k_idx, s_idx)));
                 end
            end
        end
    end
    data = data';
 end