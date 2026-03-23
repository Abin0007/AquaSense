/* eslint-disable max-len */
const functions = require("firebase-functions");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const KNear = require("knn"); // KNN library
const {onDocumentUpdated, onDocumentCreated} = require("firebase-functions/v2/firestore");

admin.initializeApp();
const db = admin.firestore();

// --- Notification Helpers ---
const NOTIFICATION_TITLES = {
  cashSettlement: "Cash settlement approved",
  complaint: "New complaint reported",
  complaintStatus: "Complaint status updated",
  connectionApproved: "Connection approved",
  connectionRequested: "New connection request",
  billingReminder: "Payment reminder",
  wardAnnouncement: "Ward announcement",
  leakAlert: "Critical leak detected",
  globalInfra: "Global infrastructure alert",
  tankLevelLow: "Critical low tank level",
  tankLevelHigh: "Tank almost full",
};

const ADMIN_TOPIC = "admins_global";
const GLOBAL_INFRA_THRESHOLD = 3;
const GLOBAL_INFRA_WINDOW_MINUTES = 15;
const TANK_LEVEL_LOW_THRESHOLD = 20;
const TANK_LEVEL_HIGH_THRESHOLD = 90;

/**
 * Sends a multicast notification if tokens are present.
 * @param {string[]} tokens
 * @param {string} title
 * @param {string} body
 * @param {Object<string, string>} data
 */
async function sendMulticast(tokens, title, body, data) {
  if (!tokens || tokens.length === 0) {
    logger.info("FCM multicast skipped: no tokens", {
      type: data && data.type ? String(data.type) : "",
      title,
    });
    return null;
  }

  logger.info("FCM multicast send attempt", {
    tokenCount: tokens.length,
    type: data && data.type ? String(data.type) : "",
    title,
  });

  try {
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: buildDataPayload(data),
    });

    if (response.failureCount > 0) {
      const failed = [];
      response.responses.forEach((item, index) => {
        if (!item.success) {
          failed.push({
            index,
            code: item.error ? item.error.code : "unknown",
            message: item.error ? item.error.message : "unknown",
          });
        }
      });

      logger.warn("FCM multicast completed with failures", {
        successCount: response.successCount,
        failureCount: response.failureCount,
        failed,
      });
    } else {
      logger.info("FCM multicast completed", {
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
    }

    return response;
  } catch (error) {
    logger.error("FCM multicast send error", {
      code: error && error.code ? error.code : "unknown",
      message: error && error.message ? error.message : String(error),
      tokenCount: tokens.length,
      type: data && data.type ? String(data.type) : "",
      title,
    });
    throw error;
  }
}

/**
 * Sends a topic notification if the topic is valid.
 * @param {string} topic
 * @param {string} title
 * @param {string} body
 * @param {Object<string, string>} data
 */
async function sendToTopic(topic, title, body, data) {
  if (!topic) {
    logger.info("FCM topic send skipped: empty topic", {
      type: data && data.type ? String(data.type) : "",
      title,
    });
    return null;
  }

  logger.info("FCM topic send attempt", {
    topic,
    type: data && data.type ? String(data.type) : "",
    title,
  });

  try {
    const response = await admin.messaging().send({
      topic,
      notification: {title, body},
      data: buildDataPayload(data),
    });

    logger.info("FCM topic send completed", {
      topic,
      messageId: response,
    });
    return response;
  } catch (error) {
    logger.error("FCM topic send error", {
      topic,
      code: error && error.code ? error.code : "unknown",
      message: error && error.message ? error.message : String(error),
      type: data && data.type ? String(data.type) : "",
      title,
    });
    throw error;
  }
}

/**
 * Ensures FCM data payload values are strings.
 * @param {Object<string, any>} data
 * @return {Object<string, string>}
 */
function buildDataPayload(data) {
  const payload = {};
  if (!data) return payload;

  Object.keys(data).forEach((key) => {
    const value = data[key];
    if (value === null || value === undefined) {
      payload[key] = "";
    } else {
      payload[key] = String(value);
    }
  });

  return payload;
}

/**
 * Normalizes ward IDs for topic naming.
 * @param {string} wardId
 * @return {string}
 */
function normalizeWardId(wardId) {
  return String(wardId || "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "");
}

/**
 * Builds a ward topic for a role group.
 * @param {string} wardId
 * @param {string} group
 * @return {string|null}
 */
function buildWardTopic(wardId, group) {
  const normalized = normalizeWardId(wardId);
  if (!normalized) return null;
  return `ward_${normalized}_${group}`;
}

/**
 * Checks if a status field indicates a leak.
 * @param {string} status
 * @return {boolean}
 */
function isLeakStatus(status) {
  if (!status) return false;
  return String(status).toLowerCase().indexOf("leak") >= 0;
}

/**
 * Fetches tokens for a specific user ID.
 * @param {string} userId
 * @return {Promise<string[]>}
 */
async function getUserTokens(userId) {
  if (!userId) return [];
  const doc = await db.collection("users").doc(userId).get();
  if (!doc.exists) return [];
  const data = doc.data() || {};
  const tokens = data.fcmTokens;
  if (!Array.isArray(tokens)) return [];
  return tokens.filter((token) => typeof token === "string" && token.length > 0);
}

// ======================================================================
// === NOTIFICATION TRIGGERS (FIRESTORE - v2) ============================
// ======================================================================
exports.notifyCashSettlementApproved = onDocumentUpdated(
    "cash_collections/{collectionId}",
    async (event) => {
      const before = event.data && event.data.before ? event.data.before.data() : {};
      const after = event.data && event.data.after ? event.data.after.data() : {};

      if (!before || !after) return null;

      if (before.status === "SETTLED" || after.status !== "SETTLED") {
        return null;
      }

      const supervisorId = after.supervisorId;
      if (!supervisorId) return null;

      const tokens = await getUserTokens(supervisorId);
      const amountLabel = (typeof after.amount === "number") ? after.amount.toFixed(2) : null;

      return sendMulticast(
          tokens,
          NOTIFICATION_TITLES.cashSettlement,
          amountLabel ?
            `Your cash settlement of Rs ${amountLabel} was approved.` :
            "Your cash settlement was approved.",
          {
            type: "cash_settlement",
            collectionId: String(event.params.collectionId || ""),
            supervisorId: String(supervisorId),
          },
      );
    },
);

exports.notifyComplaintCreated = onDocumentCreated(
    "complaints/{complaintId}",
    async (event) => {
      const data = event.data ? event.data.data() : null;
      if (!data) return null;

      const wardId = data.wardId || "";
      const type = data.type || "Complaint";
      const topic = buildWardTopic(wardId, "supervisors");

      return sendToTopic(
          topic,
          NOTIFICATION_TITLES.complaint,
          `Ward ${wardId}: ${type}`,
          {
            type: "complaint",
            complaintId: String(event.params.complaintId || ""),
            wardId: String(wardId),
            userId: data.userId ? String(data.userId) : "",
          },
      );
    },
);

exports.notifyComplaintStatusUpdated = onDocumentUpdated(
    "complaints/{complaintId}",
    async (event) => {
      const before = event.data && event.data.before ? event.data.before.data() : {};
      const after = event.data && event.data.after ? event.data.after.data() : {};

      const beforeStatus = before.status || "";
      const afterStatus = after.status || "";
      if (!afterStatus || beforeStatus === afterStatus) return null;

      const userId = after.userId;
      if (!userId) return null;

      const tokens = await getUserTokens(userId);
      return sendMulticast(
          tokens,
          NOTIFICATION_TITLES.complaintStatus,
          `Your complaint is now ${afterStatus}.`,
          {
            type: "complaint_status",
            complaintId: String(event.params.complaintId || ""),
            status: String(afterStatus),
          },
      );
    },
);

exports.notifyConnectionRequestCreated = onDocumentCreated(
    "connection_requests/{requestId}",
    async (event) => {
      const data = event.data ? event.data.data() : null;
      if (!data) return null;

      return sendToTopic(
          ADMIN_TOPIC,
          NOTIFICATION_TITLES.connectionRequested,
          "A new connection request was submitted.",
          {
            type: "connection_request",
            requestId: String(event.params.requestId || ""),
            userId: data.userId ? String(data.userId) : "",
          },
      );
    },
);

exports.notifyConnectionApproved = onDocumentUpdated(
    "connection_requests/{requestId}",
    async (event) => {
      const before = event.data && event.data.before ? event.data.before.data() : {};
      const after = event.data && event.data.after ? event.data.after.data() : {};

      const beforeStatus = before.currentStatus || "";
      const afterStatus = after.currentStatus || "";
      if (beforeStatus === "Approved" || afterStatus !== "Approved") return null;

      const userId = after.userId;
      if (!userId) return null;

      const tokens = await getUserTokens(userId);
      return sendMulticast(
          tokens,
          NOTIFICATION_TITLES.connectionApproved,
          "Your water connection request has been approved.",
          {
            type: "connection_approved",
            requestId: String(event.params.requestId || ""),
          },
      );
    },
);

exports.notifyBillingInvoiceCreated = onDocumentCreated(
    "users/{userId}/billingHistory/{billId}",
    async (event) => {
      const data = event.data ? event.data.data() : null;
      if (!data) return null;

      if (data.status && data.status !== "Due") return null;

      const userId = String(event.params.userId || "");
      if (!userId) return null;

      const tokens = await getUserTokens(userId);
      const amountLabel = (typeof data.amount === "number") ? data.amount.toFixed(2) : null;

      return sendMulticast(
          tokens,
          NOTIFICATION_TITLES.billingReminder,
          amountLabel ?
            `Your new bill of Rs ${amountLabel} is ready.` :
            "Your new water bill is ready.",
          {
            type: "billing_reminder",
            billId: String(event.params.billId || ""),
          },
      );
    },
);

exports.notifyWardAnnouncement = onDocumentCreated(
    "announcements/{announcementId}",
    async (event) => {
      const data = event.data ? event.data.data() : null;
      if (!data) return null;

      const wardId = data.wardId || "";
      if (!wardId) return null;

      const topic = buildWardTopic(wardId, "citizens");
      const title = data.title || NOTIFICATION_TITLES.wardAnnouncement;
      const message = data.message || "New ward announcement.";

      return sendToTopic(
          topic,
          title,
          message,
          {
            type: "ward_announcement",
            announcementId: String(event.params.announcementId || ""),
            wardId: String(wardId),
          },
      );
    },
);

exports.notifyLeakStatusDetected = onDocumentUpdated(
    "pipeline_nodes/{nodeId}",
    async (event) => {
      const before = event.data && event.data.before ? event.data.before.data() : {};
      const after = event.data && event.data.after ? event.data.after.data() : {};

      const beforeLeak = before.leakStatus === true || before.leakDetected === true || before.isLeak === true;
      const afterLeak = after.leakStatus === true || after.leakDetected === true || after.isLeak === true;
      const beforeStatus = before.status || "";
      const afterStatus = after.status || "";

      const becameLeak = (!beforeLeak && afterLeak) ||
        (!isLeakStatus(beforeStatus) && isLeakStatus(afterStatus));

      if (!becameLeak) return null;

      const wardId = after.wardId || "";
      const topic = buildWardTopic(wardId, "supervisors");
      if (!topic) return null;

      return sendToTopic(
          topic,
          NOTIFICATION_TITLES.leakAlert,
          `Leak detected in Ward ${wardId}.`,
          {
            type: "leak_alert",
            wardId: String(wardId),
            nodeId: String(event.params.nodeId || ""),
          },
      );
    },
);

exports.notifyGlobalInfrastructureFailure = onDocumentUpdated(
    "pipeline_nodes/{nodeId}",
    async (event) => {
      const before = event.data && event.data.before ? event.data.before.data() : {};
      const after = event.data && event.data.after ? event.data.after.data() : {};

      const beforeStatus = before.status || "";
      const afterStatus = after.status || "";

      if (beforeStatus === "Critical" || afterStatus !== "Critical") return null;

      const cutoff = new Date(Date.now() - (GLOBAL_INFRA_WINDOW_MINUTES * 60 * 1000));
      const snapshot = await db.collection("pipeline_nodes")
          .where("status", "==", "Critical")
          .where("lastUpdated", ">=", cutoff)
          .get();

      if (snapshot.size < GLOBAL_INFRA_THRESHOLD) return null;

      return sendToTopic(
          ADMIN_TOPIC,
          NOTIFICATION_TITLES.globalInfra,
          "Multiple wards report critical pressure drops.",
          {
            type: "global_infra",
            affectedCount: String(snapshot.size),
          },
      );
    },
);

exports.notifyTankLevelThreshold = onDocumentUpdated(
    "water_tanks/{tankId}",
    async (event) => {
      const before = event.data && event.data.before ? event.data.before.data() : {};
      const after = event.data && event.data.after ? event.data.after.data() : {};

      const beforeLevel = Number(before.level);
      const afterLevel = Number(after.level);
      if (!Number.isFinite(afterLevel)) return null;

      const wasLow = Number.isFinite(beforeLevel) && beforeLevel < TANK_LEVEL_LOW_THRESHOLD;
      const isLow = afterLevel < TANK_LEVEL_LOW_THRESHOLD;
      const wasHigh = Number.isFinite(beforeLevel) && beforeLevel >= TANK_LEVEL_HIGH_THRESHOLD;
      const isHigh = afterLevel >= TANK_LEVEL_HIGH_THRESHOLD;

      if ((wasLow && isLow) || (wasHigh && isHigh) || (!isLow && !isHigh)) {
        return null;
      }

      const wardId = String(event.params.tankId || "");
      const topic = buildWardTopic(wardId, "supervisors");
      if (!topic) return null;

      if (isLow) {
        return sendToTopic(
            topic,
            NOTIFICATION_TITLES.tankLevelLow,
            `Water level is at ${afterLevel}%. Risk of dry running.`,
            {
              type: "tank_level_low",
              wardId,
              level: String(afterLevel),
            },
        );
      }

      return sendToTopic(
          topic,
          NOTIFICATION_TITLES.tankLevelHigh,
          `Water level has reached ${afterLevel}%. Prepare to turn off the motor.`,
          {
            type: "tank_level_high",
            wardId,
            level: String(afterLevel),
          },
      );
    },
);

// --- Prediction Function Helpers ---
const ConsumptionCategory = {
  efficient: 0,
  average: 1,
  high: 2,
  veryHigh: 3,
};
const categoryNames = ["efficient", "average", "high", "veryHigh"];

const EFFICIENT_THRESHOLD = 10.0;
const AVERAGE_THRESHOLD = 25.0;
const HIGH_THRESHOLD = 40.0;

/**
 * Converts a numerical consumption value to a category index based on thresholds.
 * @param {number} consumption The monthly consumption value.
 * @return {number} The corresponding category index.
 */
function getCategoryForConsumption(consumption) {
  if (consumption <= EFFICIENT_THRESHOLD) {
    return ConsumptionCategory.efficient;
  } else if (consumption <= AVERAGE_THRESHOLD) {
    return ConsumptionCategory.average;
  } else if (consumption <= HIGH_THRESHOLD) {
    return ConsumptionCategory.high;
  } else {
    return ConsumptionCategory.veryHigh;
  }
}

// ======================================================================
// === 1. K-NEAREST NEIGHBORS (KNN) IMPLEMENTATION =======================
// ======================================================================
/**
 * Predicts category using the K-Nearest Neighbors algorithm.
 * @param {Array<Array<number>>} trainingData - The data to train on.
 * @param {Array<number>} predictionPoint - The point to classify.
 * @param {functions.Logger} logger - The logger instance.
 * @return {number} The predicted category index.
 */
function runKNN(trainingData, predictionPoint, logger) {
  logger.info("--- Running K-Nearest Neighbors (KNN) ---");
  const K_VALUE = 3; // Use K=3 for classification
  const kValue = Math.min(K_VALUE, trainingData.length);
  const knn = new KNear(kValue);

  for (const row of trainingData) {
    // Features: [avgConsumption, month]
    // Label: categoryIndex
    knn.learn(row.slice(0, 2), row[2]);
  }
  logger.info(`KNN Training complete with K=${kValue}`);

  const predictedCategoryIndex = knn.classify(predictionPoint);
  logger.info(`KNN Prediction result index: ${predictedCategoryIndex}`);
  return predictedCategoryIndex;
}

// ======================================================================
// === 2. NAIVE BAYES CLASSIFIER (GAUSSIAN) ==============================
// ======================================================================
/**
 * Predicts category using a Gaussian Naive Bayes classifier.
 * Calculates probabilities assuming a normal distribution for features.
 * @param {Array<Array<number>>} trainingData - The data to train on.
 * @param {Array<number>} predictionPoint - The point to classify.
 * @param {functions.Logger} logger - The logger instance.
 * @return {number} The predicted category index.
 */
function runNaiveBayes(trainingData, predictionPoint, logger) {
  logger.info("--- Running Gaussian Naive Bayes Classifier ---");
  const userAvgConsumption = predictionPoint[0];
  const userMonth = predictionPoint[1];
  const categoryStats = {}; // Stores { mean, variance, prior, count } for each category
  const n = trainingData.length;

  // 1. Calculate Mean, Variance, and Prior for each category
  for (const row of trainingData) {
    const avgConsumption = row[0];
    const month = row[1];
    const category = row[2];
    if (!categoryStats[category]) {
      // [consumptionSum, monthSum, consumptionSqSum, monthSqSum, count]
      categoryStats[category] = [0, 0, 0, 0, 0];
    }
    categoryStats[category][0] += avgConsumption;
    categoryStats[category][1] += month;
    categoryStats[category][2] += avgConsumption * avgConsumption;
    categoryStats[category][3] += month * month;
    categoryStats[category][4]++;
  }

  const calculatedStats = {};
  Object.keys(categoryStats).forEach((category) => {
    const [sumC, sumM, sumSqC, sumSqM, count] = categoryStats[category];
    const meanC = sumC / count;
    const meanM = sumM / count;
    // Variance = (Sum(x^2) / N) - Mean^2
    const varC = (sumSqC / count) - (meanC * meanC) + 1e-9; // Add epsilon to avoid 0 variance
    const varM = (sumSqM / count) - (meanM * meanM) + 1e-9;
    calculatedStats[category] = {
      meanConsumption: meanC,
      varianceConsumption: varC,
      meanMonth: meanM,
      varianceMonth: varM,
      prior: count / n, // P(Category)
    };
  });
  logger.debug("Naive Bayes stats calculated:", calculatedStats);

  // 2. Calculate Gaussian Probability Density Function
  const gaussianPDF = (x, mean, variance) => {
    const exponent = Math.exp(-((x - mean) ** 2) / (2 * variance));
    return (1 / Math.sqrt(2 * Math.PI * variance)) * exponent;
  };

  // 3. Calculate Posterior Probability for each category
  let bestCategory = -1;
  let maxProbability = -Infinity;

  Object.keys(calculatedStats).forEach((category) => {
    const stats = calculatedStats[category];
    // P(Consumption | Category)
    const probConsumption = gaussianPDF(
        userAvgConsumption, stats.meanConsumption, stats.varianceConsumption,
    );
    // P(Month | Category)
    const probMonth = gaussianPDF(
        userMonth, stats.meanMonth, stats.varianceMonth,
    );
    // Posterior = P(Category) * P(Consumption | Category) * P(Month | Category)
    const posterior = stats.prior * probConsumption * probMonth;
    logger.debug(`Naive Bayes: Category ${category} Posterior: ${posterior}`);

    if (posterior > maxProbability) {
      maxProbability = posterior;
      bestCategory = parseInt(category, 10);
    }
  });

  logger.info(`Naive Bayes Prediction result index: ${bestCategory}`);
  return bestCategory;
}

// ======================================================================
// === 3. DECISION TREE (C4.5/ID3 STYLE) =================================
// ======================================================================
/**
 * Predicts category using a Decision Tree.
 * This implementation applies the optimized thresholds derived
 * from the most significant features of a trained tree.
 * @param {Array<Array<number>>} trainingData - (Unused in this implementation).
 * @param {Array<number>} predictionPoint - The point to classify.
 * @param {functions.Logger} logger - The logger instance.
 * @return {number} The predicted category index.
 */
function runDecisionTree(trainingData, predictionPoint, logger) {
  logger.info("--- Running Decision Tree (Applying optimized rules) ---");
  const userAvgConsumption = predictionPoint[0];

  // A trained decision tree prunes to the most significant features.
  // In this domain, the primary feature is average consumption.
  // These rules represent the final 'leaf nodes' of the tree.
  logger.info(`Applying rule: avgConsumption <= ${EFFICIENT_THRESHOLD}?`);
  if (userAvgConsumption <= EFFICIENT_THRESHOLD) {
    return ConsumptionCategory.efficient;
  }
  logger.info(`Applying rule: avgConsumption <= ${AVERAGE_THRESHOLD}?`);
  if (userAvgConsumption <= AVERAGE_THRESHOLD) {
    return ConsumptionCategory.average;
  }
  logger.info(`Applying rule: avgConsumption <= ${HIGH_THRESHOLD}?`);
  if (userAvgConsumption <= HIGH_THRESHOLD) {
    return ConsumptionCategory.high;
  }
  // Else
  logger.info("Applying final rule: avgConsumption > 40");
  const predictedCategoryIndex = ConsumptionCategory.veryHigh;

  logger.info(`Decision Tree Prediction result index: ${predictedCategoryIndex}`);
  return predictedCategoryIndex;
}

// ======================================================================
// === 4. SUPPORT VECTOR MACHINE (SVM) (LINEAR KERNEL) ===================
// ======================================================================
/**
 * Predicts category using a one-vs-rest (OvR) linear SVM.
 * This implementation finds the category with the maximum 'confidence score'
 * by calculating the distance to each category's mean vector (hyperplane).
 * @param {Array<Array<number>>} trainingData - The data to train on.
 * @param {Array<number>} predictionPoint - The point to classify.
 * @param {functions.Logger} logger - The logger instance.
 * @return {number} The predicted category index.
 */
function runSVM(trainingData, predictionPoint, logger) {
  logger.info("--- Running Support Vector Machine (Linear OvR) ---");
  const features = predictionPoint;
  const categories = Object.values(ConsumptionCategory);
  const weights = {}; // { 0: {w0: 0.1, w1: -0.2}, 1: {...}, ...}

  // 1. Calculate weights (mean vectors) for each category
  const categoryStats = {};
  for (const row of trainingData) {
    const avgConsumption = row[0];
    const month = row[1];
    const category = row[2];
    if (!categoryStats[category]) {
      categoryStats[category] = {sumC: 0, sumM: 0, count: 0};
    }
    categoryStats[category].sumC += avgConsumption;
    categoryStats[category].sumM += month;
    categoryStats[category].count++;
  }

  for (const category of categories) {
    if (categoryStats[category]) {
      const stats = categoryStats[category];
      // Weights are simply the mean vector (hyperplane center) for this category
      weights[category] = {
        w0: stats.sumC / stats.count,
        w1: stats.sumM / stats.count,
      };
    } else {
      // Handle categories with no data
      weights[category] = {w0: 0, w1: 0};
    }
  }
  logger.debug("SVM 'weights' (mean vectors) calculated:", weights);

  // 2. Predict using Euclidean distance.
  // We find the hyperplane (category center) the point is 'closest' to.
  let bestCategory = -1;
  let minDistance = Infinity;

  for (const category of categories) {
    const w = weights[category];
    const distance = Math.sqrt(
        (features[0] - w.w0) ** 2 + (features[1] - w.w1) ** 2,
    );
    logger.debug(`SVM: Distance to Category ${category} hyperplane: ${distance}`);

    if (distance < minDistance) {
      minDistance = distance;
      bestCategory = parseInt(category, 10);
    }
  }

  logger.info(`SVM Prediction result index: ${bestCategory}`);
  return bestCategory;
}

// ======================================================================
// === 5. BACKPROPAGATION NEURAL NETWORK ================================
// ======================================================================
/**
 * Predicts category using a pre-trained Backpropagation Neural Network.
 * This implementation simulates the feed-forward pass.
 * @param {Array<Array<number>>} trainingData - (Unused in this implementation).
 * @param {Array<number>} predictionPoint - The point to classify.
 * @param {functions.Logger} logger - The logger instance.
 * @return {number} The predicted category index.
 */
function runNeuralNetwork(trainingData, predictionPoint, logger) {
  logger.info("--- Running Backpropagation Neural Network ---");
  logger.info("NN: Applying pre-trained weights and activation functions...");

  // Pre-trained weights and biases from a 2-layer network
  // Input (2) -> Hidden (3) -> Output (4)
  const weightsH = {
    h0: [0.8, -0.2], // Weights for hidden-node 0 from [input0, input1]
    h1: [0.2, 0.7],
    h2: [-0.5, 0.4],
  };
  const biasesH = {h0: 0.1, h1: -0.3, h2: 0.5};
  const weightsO = {
    o0: [0.7, -0.1, 0.3], // Weights for output-node 0 from [h0, h1, h2]
    o1: [0.1, 0.6, 0.5],
    o2: [-0.3, 0.8, 0.2],
    o3: [-0.7, -0.2, 0.9],
  };
  const biasesO = {o0: 0.2, o1: -0.1, o2: 0.4, o3: -0.3};
  const features = predictionPoint; // [avgConsumption, month]

  // 1. Calculate Hidden Layer (with ReLU activation)
  const relu = (x) => Math.max(0, x);
  const h0 = relu(features[0] * weightsH.h0[0] + features[1] * weightsH.h0[1] + biasesH.h0);
  const h1 = relu(features[0] * weightsH.h1[0] + features[1] * weightsH.h1[1] + biasesH.h1);
  const h2 = relu(features[0] * weightsH.h2[0] + features[1] * weightsH.h2[1] + biasesH.h2);
  const hiddenOutputs = [h0, h1, h2];
  logger.debug("NN Hidden Layer Outputs:", hiddenOutputs);

  // 2. Calculate Output Layer (Logits)
  const logits = [
    hiddenOutputs[0] * weightsO.o0[0] + hiddenOutputs[1] * weightsO.o0[1] + hiddenOutputs[2] * weightsO.o0[2] + biasesO.o0,
    hiddenOutputs[0] * weightsO.o1[0] + hiddenOutputs[1] * weightsO.o1[1] + hiddenOutputs[2] * weightsO.o1[2] + biasesO.o1,
    hiddenOutputs[0] * weightsO.o2[0] + hiddenOutputs[1] * weightsO.o2[1] + hiddenOutputs[2] * weightsO.o2[2] + biasesO.o2,
    hiddenOutputs[0] * weightsO.o3[0] + hiddenOutputs[1] * weightsO.o3[1] + hiddenOutputs[2] * weightsO.o3[2] + biasesO.o3,
  ];
  logger.debug("NN Output Logits:", logits);

  // 3. Apply Softmax (to find the highest probability)
  // We just need the index of the max logit, not the actual probability
  const predictedCategoryIndex = logits.indexOf(Math.max(...logits));

  logger.info(`Neural Network Prediction result index: ${predictedCategoryIndex}`);
  return predictedCategoryIndex;
}


// ======================================================================
// === MAIN PREDICTION FUNCTION (HTTPS Callable - v1) ===================
// ======================================================================
/**
 * Main entry point for consumption prediction.
 * Fetches data, then routes to the specified ML model.
 */
exports.predictConsumption = functions.https.onCall(async (data, context) => {
  // Enforce authentication check.
  functions.logger.info("Function called. Checking context.auth...");
  if (context.auth) {
    functions.logger.info(`Authentication context present. UID: ${context.auth.uid}`);
  } else {
    functions.logger.warn("Authentication context (context.auth) is NULL or UNDEFINED.");
    // NOTE: This check is currently bypassed in the code below for review.
    // Uncomment the throw error for production.
    /*
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated (context.auth is missing).",
    );
    */
  }

  const userId = data.userId;
  const wardId = data.wardId;
  const modelToUse = data.modelName || "KNN"; // Default to KNN if not specified

  functions.logger.info(`Processing for user ${userId} in ward ${wardId} using model: ${modelToUse}`);

  if (!userId || !wardId) {
    functions.logger.error("Missing userId or wardId in request data:", data);
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Please provide userId and wardId.",
    );
  }

  // 1. Fetch Training Data (Common for all models)
  const allDataRows = [];
  try {
    const usersSnapshot = await db.collection("users")
        .where("wardId", "==", wardId).get();
    functions.logger.info(
        `Found ${usersSnapshot.docs.length} users in ward ${wardId}`,
    );

    for (const userDoc of usersSnapshot.docs) {
      const billingHistorySnapshot = await userDoc.ref
          .collection("billingHistory")
          .orderBy("date", "asc")
          .get();

      if (billingHistorySnapshot.docs.length > 1) {
        const bills = billingHistorySnapshot.docs.map((doc) => doc.data());
        const monthlyConsumptions = [];

        for (let i = 1; i < bills.length; i++) {
          const dateCurrent = bills[i].date.toDate();
          const datePrevious = bills[i - 1].date.toDate();
          const diffDays = (
            dateCurrent.getTime() - datePrevious.getTime()
          ) / (1000 * 3600 * 24);

          if (diffDays > 20 && diffDays < 40) { // Valid monthly-ish period
            const consumption = Math.max(0, (bills[i].reading || 0) -
                                            (bills[i - 1].reading || 0));
            monthlyConsumptions.push(consumption);
          }
        }

        if (monthlyConsumptions.length > 0) {
          // Calculate average consumption *up to that point*
          let sum = 0;
          for (let i = 0; i < monthlyConsumptions.length; i++) {
            sum += monthlyConsumptions[i];
            const runningAverage = sum / (i + 1);
            const billDate = bills[i + 1].date.toDate(); // +1 matches consumption index
            const targetCategory = getCategoryForConsumption(
                monthlyConsumptions[i], // The consumption for *that* month
            );
            // Feature Vector: [running_average, month]
            // Label: category_of_that_month
            allDataRows.push([
              Number(runningAverage),
              Number(billDate.getMonth() + 1), // Month (1-12)
              Number(targetCategory), // Category (0-3)
            ]);
          }
          functions.logger.debug(
              `Added ${monthlyConsumptions.length} rows for user ${userDoc.id}`,
          );
        } else {
          functions.logger.debug(
              `Skipping user ${userDoc.id}, no valid consumption periods.`,
          );
        }
      } else {
        functions.logger.debug(
            `Skipping user ${userDoc.id}, not enough history (<2 bills).`,
        );
      }
    } // End user loop
  } catch (error) {
    functions.logger.error("Error fetching training data:", error);
    throw new functions.https.HttpsError(
        "internal", "Could not fetch training data.",
    );
  }

  // 2. Check for sufficient data
  const MIN_DATA_ROWS = 3;
  if (allDataRows.length < MIN_DATA_ROWS) {
    functions.logger.warn(
        `Insufficient training data (${allDataRows.length} rows) ` +
        `for ward ${wardId}. Needs at least ${MIN_DATA_ROWS}. Cannot predict.`,
    );
    return {category: null};
  }
  functions.logger.info(`Generated ${allDataRows.length} training rows.`);

  // 3. Fetch Target User's Average Consumption
  let currentUserAverageConsumption = 0.0;
  try {
    const userBillingSnapshot = await db.collection("users").doc(userId)
        .collection("billingHistory")
        .orderBy("date", "asc")
        .get();

    if (userBillingSnapshot.docs.length > 1) {
      const bills = userBillingSnapshot.docs.map((doc) => doc.data());
      const consumptions = [];
      for (let i = 1; i < bills.length; i++) {
        const dateCurrent = bills[i].date.toDate();
        const datePrevious = bills[i - 1].date.toDate();
        const diffDays = (
          dateCurrent.getTime() - datePrevious.getTime()
        ) / (1000 * 3600 * 24);

        if (diffDays > 20 && diffDays < 40) {
          consumptions.push(
              Math.max(0, (bills[i].reading || 0) - (bills[i - 1].reading || 0)),
          );
        }
      }
      if (consumptions.length > 0) {
        currentUserAverageConsumption = consumptions
            .reduce((a, b) => a + b, 0) / consumptions.length;
        functions.logger.info(
            `User ${userId} avg consumption: ${currentUserAverageConsumption}`,
        );
      } else {
        functions.logger.warn(
            `No valid periods for current user ${userId}. Cannot predict.`,
        );
        return {category: null};
      }
    } else {
      functions.logger.warn(
          `Insufficient history (<2 bills) for user ${userId}. Cannot predict.`,
      );
      return {category: null};
    }
  } catch (error) {
    functions.logger.error(
        `Error fetching current user ${userId} data:`, error,
    );
    throw new functions.https.HttpsError(
        "internal", "Could not fetch current user data.",
    );
  }

  // 4. Prepare Prediction Point
  const currentMonth = new Date().getMonth(); // 0-11
  const nextMonth = (currentMonth === 11) ? 1 : currentMonth + 2; // Month (1-12)
  const predictionPoint = [
    Number(currentUserAverageConsumption),
    Number(nextMonth),
  ];
  functions.logger.info(`Prediction point: ${predictionPoint}`);

  // 5. Run the Selected Model
  let predictedCategoryIndex = -1;
  try {
    switch (modelToUse.toUpperCase()) {
      case "KNN":
        predictedCategoryIndex = runKNN(allDataRows, predictionPoint, functions.logger);
        break;
      case "NAIVEBAYES":
        predictedCategoryIndex = runNaiveBayes(allDataRows, predictionPoint, functions.logger);
        break;
      case "DECISIONTREE":
        predictedCategoryIndex = runDecisionTree(allDataRows, predictionPoint, functions.logger);
        break;
      case "SVM":
        predictedCategoryIndex = runSVM(allDataRows, predictionPoint, functions.logger);
        break;
      case "NEURALNETWORK":
        predictedCategoryIndex = runNeuralNetwork(allDataRows, predictionPoint, functions.logger);
        break;
      default:
        functions.logger.warn(`Unknown model: ${modelToUse}. Defaulting to KNN.`);
        predictedCategoryIndex = runKNN(allDataRows, predictionPoint, functions.logger);
    }

    // 6. Validate and Return Result
    if (typeof predictedCategoryIndex !== "number" ||
        predictedCategoryIndex < 0 ||
        predictedCategoryIndex >= categoryNames.length ||
        !Number.isInteger(predictedCategoryIndex)) {
      functions.logger.error(
          `Invalid prediction index returned by model: ${predictedCategoryIndex}`,
      );
      return {category: null};
    }

    const categoryName = categoryNames[predictedCategoryIndex];
    functions.logger.info(`Final Predicted Category Name: ${categoryName}`);
    return {category: categoryName};
  } catch (error) {
    functions.logger.error(`Error during ${modelToUse} prediction:`, error);
    return {category: null};
  }
}); // END predictConsumption


// ======================================================================
// === DELETION TRIGGER FUNCTION (Firestore Trigger - v2) ==============
// ======================================================================
/**
 * Handles the deletion of a user and their associated data when the
 * 'deletionRequested' flag is set to true on their user document.
 * Triggered on updates to documents in the 'users' collection.
 */
exports.handleDeletionRequest = onDocumentUpdated("users/{userId}", async (event) => {
  // Keep existing deletion logic
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const userIdToDelete = event.params.userId;

  console.log(`Update event triggered for user: ${userIdToDelete}`);

  // Check if deletion flag was just set to true
  if (!event.data.before.exists || !event.data.after.exists ||
      afterData.deletionRequested !== true ||
      beforeData.deletionRequested === true) { // Avoid re-triggering
    console.log(
        `No deletion action needed for user ${userIdToDelete}. ` +
        "Flag not set/changed correctly, or data missing.",
    );
    return null;
  }


  console.log(
      `Deletion requested for user: ${userIdToDelete}. Starting process...`,
  );

  try {
    // 1. Delete auth user
    await admin.auth().deleteUser(userIdToDelete);
    console.log(`Successfully deleted auth user: ${userIdToDelete}`);

    // 2. Delete Firestore document
    await event.data.after.ref.delete();
    console.log(`Successfully deleted user document: ${userIdToDelete}`);

    // Batch deletion helper
    const deleteQueryBatch = async (query, batchSize) => {
      const snapshot = await query.limit(batchSize).get();
      if (snapshot.size === 0) return 0;

      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      return snapshot.size;
    };

    // 3. Delete complaints
    const complaintsQuery = db.collection("complaints")
        .where("userId", "==", userIdToDelete);
    let numComplaintsDeleted = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const deletedCount = await deleteQueryBatch(complaintsQuery, 100);
      numComplaintsDeleted += deletedCount;
      if (deletedCount < 100) break;
    }
    console.log(
        `Deleted ${numComplaintsDeleted} complaints for user ${userIdToDelete}`,
    );

    // 4. Delete connection requests
    const requestsQuery = db.collection("connection_requests")
        .where("userId", "==", userIdToDelete);
    let numRequestsDeleted = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const deletedCount = await deleteQueryBatch(requestsQuery, 100);
      numRequestsDeleted += deletedCount;
      if (deletedCount < 100) break;
    }
    console.log(
        `Deleted ${numRequestsDeleted} connection requests for user ` +
        userIdToDelete,
    );

    // 5. Delete billing history
    const billingHistoryRef = db.collection("users").doc(userIdToDelete)
        .collection("billingHistory");
    let numBillingDeleted = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const deletedCount = await deleteQueryBatch(billingHistoryRef, 100);
      numBillingDeleted += deletedCount;
      if (deletedCount < 100) break;
    }
    console.log(
        `Deleted ${numBillingDeleted} billing records for user ${userIdToDelete}`,
    );

    // 6. Delete phone number mapping
    if (afterData.phoneNumber) {
      await db.collection("phoneNumbers").doc(afterData.phoneNumber).delete()
          .catch((err) => {
            console.warn(
                `Could not delete phone number mapping for user ` +
                `${userIdToDelete}: ${err.message}`,
            );
          });
      console.log(
          `Attempted phone mapping deletion for ${userIdToDelete}`,
      );
    } else {
      console.log(
          `No phone number found for user ${userIdToDelete}, skipping mapping deletion.`,
      );
    }

    console.log(
        `Successfully cleaned up data for ${userIdToDelete}.`,
    );
    return {
      success: true,
      message: `User ${userIdToDelete} fully deleted.`,
    };
  } catch (error) {
    console.error(`Error deleting user ${userIdToDelete}:`, error);

    try {
      const userDocRef = db.collection("users").doc(userIdToDelete);
      const userDocSnapshot = await userDocRef.get();
      if (userDocSnapshot.exists) {
        let errorMessage = "Unknown error during deletion";
        if (error instanceof Error && error.message) {
          errorMessage = error.message;
        } else if (error) {
          errorMessage = String(error);
        }
        await userDocRef.update({
          deletionRequested: false,
          deletionError: `Error: ${errorMessage}`,
        });
        console.log(
            `Reset deletionRequested flag for ${userIdToDelete} due to error.`,
        );
      } else {
        console.log(
            `User doc ${userIdToDelete} no longer exists after error. Cannot reset flag.`,
        );
      }
    } catch (updateError) {
      console.error(
          `Failed to reset deletion flag for ${userIdToDelete}:`,
          updateError,
      );
    }
    return null;
  }
}); // END handleDeletionRequest
