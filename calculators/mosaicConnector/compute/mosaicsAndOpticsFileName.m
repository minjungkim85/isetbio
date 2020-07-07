function fname = mosaicsAndOpticsFileName(runParams)
    fname = sprintf('MosaicsAndOpticsForEccentricity_%2.0f_%2.0f_%2.0f_%2.0f_microns_coneSpecificity_%2.0f_orphanPolicy_%s_PolansSID_%d.mat', ...
        runParams.rgcMosaicPatchEccMicrons(1), runParams.rgcMosaicPatchEccMicrons(2), ...
        runParams.rgcMosaicPatchSizeMicrons(1), runParams.rgcMosaicPatchSizeMicrons(2), ...
        runParams.maximizeConeSpecificity, runParams.orphanRGCpolicy, runParams.PolansWavefrontAberrationSubjectID);
end
